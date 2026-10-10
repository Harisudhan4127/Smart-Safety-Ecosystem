"""Demo Mode animation for the Smart Safety Ecosystem wristband node.

Renders a short sequence that mirrors what the application's Demo Mode shows:

  1. the assembled unit, turning on its axis
  2. the lid lifting to expose the internals
  3. the status indicators escalating through the AWTRA risk bands
     (safe -> medium risk -> high risk), with the display colour following
  4. the lid closing and the camera settling on a final view

Nothing here claims measured performance: the indicators are a scripted
illustration of the documented band logic, not a test result.

Run with:
    blender --background --python render_demo.py -- <output_dir>
"""

import glob
import math
import os
import shutil
import subprocess
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sse_blender import (  # noqa: E402
    MAT,
    box,
    build_palette,
    camera,
    material,
    reset_scene,
    set_color_management,
    set_engine,
    set_resolution,
    studio,
)
import build_enclosure as ENC  # noqa: E402

FPS = 30
FRAMES = 300

# Band colours, matching the application's severity tokens.
TEAL = (0.29, 0.84, 0.77, 1.0)
AMBER = (0.94, 0.74, 0.36, 1.0)
RED = (1.0, 0.39, 0.45, 1.0)


def _socket(bsdf, name):
    """Index of a Principled socket, by name."""
    for index, socket in enumerate(bsdf.inputs):
        if socket.name == name:
            return index
    return None


def animate_input(mat, socket_name, frames_values):
    """Keyframes a Principled input's default_value.

    `frames_values` is a list of (frame, value) pairs; `value` is a scalar or
    a colour tuple, matching the socket type.
    """
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    index = _socket(bsdf, socket_name)
    if index is None:
        raise KeyError(f"{mat.name} has no socket {socket_name}")
    prop = bsdf.inputs[index]
    for frame, value in frames_values:
        prop.default_value = value
        prop.keyframe_insert("default_value", frame=frame)


def _fcurves(action):
    """F-curves of an Action across Blender versions.

    Blender 5.x replaced the flat `Action.fcurves` list with a slotted, layered
    model, so the curves are reached through the strip's channel bag. The legacy
    path is kept for older files.
    """
    if hasattr(action, "fcurves"):
        return list(action.fcurves)

    curves = []
    for layer in action.layers:
        for strip in layer.strips:
            if strip.type != "KEYFRAME":
                continue
            for slot in action.slots:
                try:
                    bag = strip.channelbag(slot)
                except (RuntimeError, TypeError):
                    continue
                if bag is not None:
                    curves.extend(bag.fcurves)
    return curves


def _set_interpolation(objs, kind="BEZIER"):
    """Applies an interpolation mode to every F-curve of each animated object
    or material node tree."""
    for obj in objs:
        data = obj
        if hasattr(obj, "node_tree"):
            data = obj.node_tree
        if data is None or not getattr(data, "animation_data", None):
            continue
        action = data.animation_data.action
        if action is None:
            continue
        for fc in _fcurves(action):
            for kp in fc.keyframe_points:
                kp.interpolation = kind


def main():
    out_dir = "out"
    if "--" in sys.argv:
        args = sys.argv[sys.argv.index("--") + 1:]
        if args:
            out_dir = args[0]
    os.makedirs(out_dir, exist_ok=True)

    scene = reset_scene()
    build_palette()
    set_engine(scene, samples=24)
    set_resolution(scene, 1280, 720)
    set_color_management(scene)

    spec = ENC.SPEC
    parts = ENC.build_case(seated=True)
    studio(scene, dark=True)

    # --- per-indicator materials so each LED can be driven independently ----
    led_mats = [
        material("LED A", color=(0.03, 0.16, 0.09, 1.0), emission=TEAL,
                 emission_strength=7.0),
        material("LED B", color=(0.16, 0.12, 0.03, 1.0), emission=AMBER,
                 emission_strength=0.0),
        material("LED C", color=(0.18, 0.05, 0.06, 1.0), emission=RED,
                 emission_strength=0.0),
    ]
    for led, mat in zip(parts["leds"], led_mats):
        led.data.materials.clear()
        led.data.materials.append(mat)

    # Escalation: safe -> medium -> high, mirroring the AWTRA bands.
    animate_input(led_mats[0], "Emission Strength", [(1, 7.0), (290, 7.0)])
    animate_input(led_mats[1], "Emission Strength",
                  [(1, 0.0), (150, 0.0), (162, 6.0), (290, 6.0)])
    animate_input(led_mats[2], "Emission Strength",
                  [(1, 0.0), (190, 0.0), (202, 8.0), (290, 8.0)])

    # The display follows the band.
    animate_input(MAT["screen"], "Emission Color",
                  [(1, TEAL), (150, TEAL), (170, AMBER), (190, AMBER),
                   (205, RED), (290, RED)])
    animate_input(MAT["screen"], "Emission Strength",
                  [(1, 8.0), (140, 8.0), (152, 16.0), (188, 16.0),
                   (200, 22.0), (290, 22.0)])

    # --- lid motion ---------------------------------------------------------
    lift = 40.0
    for frame, z in ((1, 0.0), (86, 0.0), (150, lift), (212, lift),
                     (268, 0.0), (300, 0.0)):
        parts["lid"].location.z = spec.half_h / 2.0 + z
        parts["lid"].keyframe_insert("location", index=2, frame=frame)

    for frame, z in ((1, 0.0), (86, 0.0), (150, lift * 0.55),
                     (212, lift * 0.55), (268, 0.0), (300, 0.0)):
        for key in ("oled", "screen"):
            parts[key].location.z = (7.6 if key == "oled" else 9.7) + z
            parts[key].keyframe_insert("location", index=2, frame=frame)

    # --- camera rig ---------------------------------------------------------
    # The camera rides an empty that spins about Z, which gives a clean orbit
    # without recomputing look-at on every frame.
    rig = bpy.data.objects.new("Rig", None)
    bpy.context.collection.objects.link(rig)

    radius, height = 300.0, 150.0
    cam = camera("Camera", (radius, 0.0, height), (0, 0, 0), lens=62)
    cam.parent = rig
    # Local orientation that looks at the origin once the rig has spun.
    cam.rotation_euler = (math.atan2(radius, height), 0.0, math.pi / 2.0)

    for frame, angle in ((1, 0.0), (90, math.radians(55)),
                         (150, math.radians(95)), (212, math.radians(150)),
                         (270, math.radians(190)), (300, math.radians(205))):
        rig.rotation_euler.z = angle
        rig.keyframe_insert("rotation_euler", index=2, frame=frame)

    # A gentle push-in while the internals are exposed.
    for frame, r, h in ((1, radius, height), (90, radius, height),
                        (150, 255.0, 128.0), (212, 255.0, 128.0),
                        (270, radius, height), (300, radius, height)):
        cam.location = (r, 0.0, h)
        cam.keyframe_insert("location", frame=frame)

    animated = [rig, cam, parts["lid"], parts["oled"], parts["screen"]]
    _set_interpolation(animated)
    _set_interpolation(led_mats + [MAT["screen"]], kind="LINEAR")

    # This Blender build ships without FFMPEG output support, so the frames are
    # rendered as a PNG sequence and muxed with the system ffmpeg. That keeps
    # the pipeline working on any Blender build and lets ffmpeg do the encoding
    # properly.
    frames_dir = os.path.join(out_dir, "frames")
    if os.path.isdir(frames_dir):
        shutil.rmtree(frames_dir)
    os.makedirs(frames_dir, exist_ok=True)

    scene.camera = cam
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.image_settings.compression = 15
    scene.render.filepath = os.path.join(frames_dir, "frame_")
    scene.render.fps = FPS
    scene.frame_start = 1
    scene.frame_end = FRAMES

    bpy.ops.render.render(animation=True)

    # Mux to H.264. yuv420p keeps it playable in ordinary players and on the
    # web; -crf 18 is visually clean for this kind of gradient-heavy content.
    path = os.path.join(out_dir, "demo_mode_simulation.mp4")
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        print("FFMPEG_MISSING: frames left in", frames_dir)
    else:
        subprocess.run(
            [
                ffmpeg, "-y", "-loglevel", "error",
                "-framerate", str(FPS),
                "-i", os.path.join(frames_dir, "frame_%04d.png"),
                "-c:v", "libx264",
                "-preset", "slow",
                "-crf", "18",
                "-pix_fmt", "yuv420p",
                # Even dimensions are required by yuv420p.
                "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2",
                path,
            ],
            check=True,
        )
        # The frames are a build artefact, not a deliverable.
        shutil.rmtree(frames_dir, ignore_errors=True)
        print("FRAMES_RENDERED:", FRAMES)

    print("WROTE", path)


if __name__ == "__main__":
    main()