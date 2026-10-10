"""Shared helpers for the Smart Safety Ecosystem Blender scenes.

Units
-----
Geometry is modelled in millimetres. The scene unit scale is set to 0.001 so
one Blender unit equals one millimetre and the numbers in the code stay
readable ("box(45, 18, 1.6)" is an Arduino Nano).

Rendering
---------
Blender 5.2 in this environment exposes only the EEVEE engine, so every render
helper here targets EEVEE. No Cycles or third-party add-ons are required, which
keeps the build reproducible on a plain checkout.
"""

import math

import bpy

MM = 0.001  # one Blender unit in metres, for physical fallback


# ---------------------------------------------------------------------------
# scene setup
# ---------------------------------------------------------------------------


def reset_scene():
    """Clears the file so scripts are idempotent and can be re-run safely."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = MM
    scene.unit_settings.length_unit = "MILLIMETERS"
    return scene


def set_engine(scene, samples=32, taa=True):
    """Selects EEVEE and configures sampling.

    EEVEE Next (4.2+) uses the TAA sample count for its temporal pass; the
    property moved between versions, so both spellings are attempted.
    """
    scene.render.engine = "BLENDER_EEVEE"
    eevee = scene.eevee
    if hasattr(eevee, "taa_render_samples"):
        eevee.taa_render_samples = samples
    if hasattr(eevee, "taa_samples"):
        eevee.taa_samples = samples
    if hasattr(eevee, "use_raytracing") and taa:
        # Screen-space raytracing gives the machined edges a believable
        # reflection without a full path tracer.
        eevee.use_raytracing = True
    if hasattr(eevee, "use_shadows"):
        eevee.use_shadows = True


def set_resolution(scene, width=1600, height=1000, percentage=100):
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = percentage
    scene.render.film_transparent = False


# ---------------------------------------------------------------------------
# materials
# ---------------------------------------------------------------------------


def material(
    name,
    color=(0.5, 0.5, 0.5, 1.0),
    metallic=0.0,
    roughness=0.5,
    emission=None,
    emission_strength=0.0,
    alpha=1.0,
    transmission=0.0,
):
    """Creates a Principled BSDF material.

    Socket names follow Blender 4.x/5.x ('Emission Color', 'Emission
    Strength'), which differ from the pre-4.0 names.
    """
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")

    def put(socket, value):
        if bsdf and socket in bsdf.inputs:
            bsdf.inputs[socket].default_value = value

    put("Base Color", color)
    put("Metallic", metallic)
    put("Roughness", roughness)
    put("Alpha", alpha)
    put("Transmission Weight", transmission)

    if emission is not None:
        put("Emission Color", emission)
        put("Emission Strength", emission_strength)

    if alpha < 1.0 or transmission > 0.0:
        mat.blend_method = "BLEND"
    return mat


# Palette shared by every scene so the renders match the application themes.
MAT = {}


def build_palette():
    """Materials drawn from the application's light and dark token palettes."""
    MAT["shell"] = material(
        "Enclosure shell",
        color=(0.030, 0.034, 0.042, 1.0),
        metallic=0.18,
        roughness=0.40,
    )
    MAT["shell_light"] = material(
        "Enclosure shell light",
        color=(0.84, 0.86, 0.885, 1.0),
        metallic=0.05,
        roughness=0.38,
    )
    MAT["pcb"] = material(
        "PCB",
        color=(0.02, 0.16, 0.11, 1.0),
        metallic=0.1,
        roughness=0.55,
    )
    MAT["nano"] = material(
        "Arduino Nano",
        color=(0.02, 0.24, 0.42, 1.0),
        metallic=0.1,
        roughness=0.45,
    )
    MAT["metal"] = material(
        "Brass and contacts",
        color=(0.72, 0.55, 0.22, 1.0),
        metallic=1.0,
        roughness=0.28,
    )
    MAT["alu"] = material(
        "Aluminium",
        color=(0.62, 0.64, 0.67, 1.0),
        metallic=1.0,
        roughness=0.34,
    )
    MAT["black_plastic"] = material(
        "Sensor body",
        color=(0.02, 0.022, 0.026, 1.0),
        metallic=0.0,
        roughness=0.55,
    )
    MAT["glass"] = material(
        "OLED glass",
        color=(0.01, 0.012, 0.015, 1.0),
        metallic=0.0,
        roughness=0.12,
    )
    MAT["led_green"] = material(
        "LED safe",
        color=(0.05, 0.35, 0.18, 1.0),
        emission=(0.29, 0.96, 0.56, 1.0),
        emission_strength=6.0,
    )
    MAT["led_amber"] = material(
        "LED caution",
        color=(0.4, 0.28, 0.05, 1.0),
        emission=(0.94, 0.74, 0.36, 1.0),
        emission_strength=6.0,
    )
    MAT["led_red"] = material(
        "LED critical",
        color=(0.4, 0.08, 0.1, 1.0),
        emission=(1.0, 0.39, 0.45, 1.0),
        emission_strength=7.0,
    )
    MAT["screen"] = material(
        "OLED backlight",
        color=(0.02, 0.05, 0.06, 1.0),
        emission=(0.29, 0.84, 0.77, 1.0),
        emission_strength=14.0,
    )
    MAT["battery"] = material(
        "LiPo pouch",
        color=(0.12, 0.14, 0.17, 1.0),
        metallic=0.65,
        roughness=0.36,
    )
    MAT["strap"] = material(
        "Watch strap",
        color=(0.020, 0.021, 0.025, 1.0),
        roughness=0.78,
    )
    MAT["floor_dark"] = material(
        "Floor dark",
        color=(0.028, 0.032, 0.04, 1.0),
        roughness=0.32,
    )
    MAT["floor_light"] = material(
        "Floor light",
        color=(0.72, 0.75, 0.78, 1.0),
        roughness=0.30,
    )
    return MAT


# ---------------------------------------------------------------------------
# primitives
# ---------------------------------------------------------------------------


def box(name, size, location=(0, 0, 0), mat=None, rotation=(0, 0, 0)):
    """Axis-aligned box given full dimensions in millimetres."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.dimensions = size
    _apply_scale(obj)
    if mat is not None:
        obj.data.materials.append(mat)
    return obj


def cylinder(
    name,
    radius,
    depth,
    location=(0, 0, 0),
    rotation=(0, 0, 0),
    vertices=48,
    mat=None,
):
    bpy.ops.mesh.primitive_cylinder_add(
        radius=radius,
        depth=depth,
        vertices=vertices,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.active_object
    obj.name = name
    if mat is not None:
        obj.data.materials.append(mat)
    shade_smooth(obj)
    return obj


def sphere(name, radius, location=(0, 0, 0), mat=None):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=location)
    obj = bpy.context.active_object
    obj.name = name
    if mat is not None:
        obj.data.materials.append(mat)
    shade_smooth(obj)
    return obj


def shade_smooth(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def _apply_scale(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.select_set(False)


def rounded(obj, width=0.8, segments=3):
    """Bevels hard edges; this is what makes the shell read as moulded rather
    than as a raw boolean result."""
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(30)
    apply_modifier(obj, mod)


def apply_modifier(obj, mod):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.select_set(False)


def subtract(target, cutter):
    """Boolean difference, then removes the cutter."""
    mod = target.modifiers.new("Cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = cutter
    mod.solver = "EXACT"
    apply_modifier(target, mod)
    bpy.data.objects.remove(cutter, do_unlink=True)
    return target


def subtract_all(target, cutters):
    for cutter in cutters:
        subtract(target, cutter)
    return target


def join(objects, name):
    """Joins parts into one object so the assembly can be animated as a unit."""
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name
    bpy.ops.object.select_all(action="DESELECT")
    return joined


def parent_to(child, parent):
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()
    return child


# ---------------------------------------------------------------------------
# text
# ---------------------------------------------------------------------------


def text_object(
    name,
    body,
    size,
    location=(0, 0, 0),
    rotation=(0, 0, 0),
    mat=None,
    align="CENTER",
    extrude=0.0,
):
    curve = bpy.data.curves.new(name, type="FONT")
    curve.body = body
    curve.size = size
    curve.align_x = align
    curve.align_y = "CENTER"
    curve.extrude = extrude
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = rotation
    if mat is not None:
        curve.materials.append(mat)
    return obj


# ---------------------------------------------------------------------------
# camera, lights, world
# ---------------------------------------------------------------------------


def look_at(obj, target=(0, 0, 0)):
    """Points an object's -Z axis at `target`, with +Y up."""
    dx = target[0] - obj.location[0]
    dy = target[1] - obj.location[1]
    dz = target[2] - obj.location[2]
    horizontal = math.hypot(dx, dy)
    pitch = math.atan2(horizontal, -dz)
    yaw = math.atan2(dy, dx) - math.pi / 2.0
    obj.rotation_euler = (pitch, 0.0, yaw)
    return obj


def camera(name, location, target=(0, 0, 0), lens=70, ortho=None):
    cam_data = bpy.data.cameras.new(name)
    cam_data.lens = lens
    if ortho is not None:
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = ortho
    cam = bpy.data.objects.new(name, cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = location
    look_at(cam, target)
    return cam


# Blender's renderer treats one Blender unit as one metre for light falloff,
# regardless of the display unit scale. Because the geometry is modelled in
# millimetres, distances are ~1000x larger than a real desk object and wattages
# must be scaled by ~1000^2 or the scene renders almost black.
WATT_SCALE = 9.0e5


def area_light(name, location, target, size=120, energy=1200, color=(1, 1, 1)):
    data = bpy.data.lights.new(name, type="AREA")
    data.size = size
    data.energy = energy * WATT_SCALE
    data.color = color
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    look_at(obj, target)
    return obj


def studio(scene, key=1.6, fill=0.6, rim=1.3, dark=True,
             world_strength=0.035, floor_z=-18.0):
    """A three-point studio plus a soft ground plane.

    The setup deliberately avoids coloured rim lights: the brief calls for
    restrained highlights rather than a neon look.
    """
    target = (0, 0, 10)

    area_light("Key", (-90, -110, 150), target, size=160, energy=key)
    area_light("Fill", (130, -60, 70), target, size=200, energy=fill)
    area_light("Rim", (60, 140, 130), target, size=140, energy=rim)

    floor = box(
        "Floor",
        (900, 900, 4),
        (0, 0, floor_z),
        MAT["floor_dark"] if dark else MAT["floor_light"],
    )
    rounded(floor, width=0.4, segments=1)

    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (
            (0.02, 0.023, 0.028, 1.0) if dark else (0.5, 0.53, 0.57, 1.0)
        )
        bg.inputs[1].default_value = world_strength
    scene.world = world
    return floor


def set_color_management(scene, look="AgX", exposure=0.0):
    """AgX keeps bright highlights from clipping to pure white, which matters
    for the emissive OLED and LED materials."""
    scene.view_settings.view_transform = look
    try:
        scene.view_settings.look = "AgX - Medium Contrast"
    except TypeError:
        pass
    scene.view_settings.exposure = exposure


def render_still(scene, path, camera_obj):
    scene.camera = camera_obj
    scene.render.filepath = path
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    bpy.ops.render.render(write_still=True)
    return path


def render_video(scene, path, camera_obj, frames=240, fps=30):
    scene.camera = camera_obj
    scene.render.filepath = path
    scene.render.image_settings.file_format = "FFMPEG"
    scene.render.ffmpeg.format = "MPEG4"
    scene.render.ffmpeg.codec = "H264"
    scene.render.ffmpeg.constant_rate_factor = "HIGH"
    scene.render.ffmpeg.ffmpeg_preset = "GOOD"
    scene.render.fps = fps
    scene.frame_start = 1
    scene.frame_end = frames
    bpy.ops.render.render(animation=True)
    return path


def keyframe(obj, path, frames_values, index=-1, interp="BEZIER"):
    """Keyframes one property, e.g. keyframe(obj, "location", [(1, 0), (40, 5)])."""
    for frame, value in frames_values:
        if index >= 0:
            getattr(obj, path)[index] = value
        else:
            setattr(obj, path, value)
        obj.keyframe_insert(data_path=path, frame=frame, index=index)
    for fc in obj.animation_data.action.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = interp


def smooth(obj, path, frames_values, index=-1):
    keyframe(obj, path, frames_values, index=index, interp="BEZIER")