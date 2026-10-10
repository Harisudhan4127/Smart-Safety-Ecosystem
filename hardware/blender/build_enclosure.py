"""Parametric enclosure for the Smart Safety Ecosystem wristband node.

The component set and layout follow the built prototype photographed in
`PP Hackthon/prototype/`: an Arduino Nano, an MQ-3 alcohol sensor with its
trimming potentiometer, an MLX90614 non-contact IR temperature sensor, a 0.96"
SSD1306 OLED, a piezo buzzer, three status LEDs and a LiPo pouch cell, carried
on a watch strap.

Everything is driven by `Spec`, so a dimension change is a one-line edit and
the whole assembly regenerates.

Orientation
-----------
+X  sensor face (MQ-3 airflow, MLX90614 field of view)
-Z  wrist side
+Z  display face
+/-Y  strap ends

The case splits at z = 0: the tray holds the electronics, the lid carries the
display window and the LED holes.

Run with:
    blender --background --python build_enclosure.py -- <output_dir>
"""

import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sse_blender import (  # noqa: E402
    MAT,
    box,
    build_palette,
    camera,
    cylinder,
    join,
    material,
    render_still,
    reset_scene,
    rounded,
    set_color_management,
    set_engine,
    set_resolution,
    sphere,
    studio,
    subtract_all,
    text_object,
)


class Spec:
    """All enclosure dimensions in millimetres."""

    def __init__(self):

            self.length = 86.0   # along Y, the strap direction
            self.width = 50.0    # along X, across the wrist
            self.height = 26.0   # along Z
            self.wall = 2.2

            # Display window in the lid.
            self.oled_window = 26.0
            self.oled_x = 0.0
            self.oled_y = 6.0

            # Status LEDs in the lid.
            self.led_diameter = 5.0
            self.led_spacing = 11.0
            self.led_x = -11.0
            self.led_y = 30.0

            # MQ-3 airflow slots on the +X face.
            self.mq3_slots = 3
            self.mq3_slot_length = 24.0
            self.mq3_slot_height = 2.4
            self.mq3_slot_gap = 4.0
            self.mq3_slot_y = 26.0

            # MLX90614 field of view on the +X face.
            self.mlx_window = 12.0
            self.mlx_y = -2.0

            # Strap slots through both ends.
            self.strap_slot_width = 26.0
            self.strap_slot_height = 3.6
            self.strap_slot_z = -7.0

            # Micro-USB access on the -X edge.
            self.usb_width = 10.0
            self.usb_height = 3.4
            self.usb_y = 28.0

            self.half_h = self.height / 2.0
            # Top surface of the tray floor: components rest here.
            self.floor_z = -self.half_h + self.wall
            # The z = 0 parting line between tray and lid.
            self.rim_z = 0.0


SPEC = Spec()


# ---------------------------------------------------------------------------
# shells
# ---------------------------------------------------------------------------


def build_tray(spec=SPEC, shell=None):
    """The lower half: a rounded tub with a solid floor and every opening."""
    outer = box(
        "Shell tray",
        (spec.width, spec.length, spec.half_h),
        (0, 0, -spec.half_h / 2.0),
        shell or MAT["shell"],
    )

    # Carve the cavity, leaving `wall` of floor behind.
    cavity_h = spec.half_h - spec.wall
    cavity = box(
        "Cavity",
        (spec.width - 2 * spec.wall, spec.length - 2 * spec.wall, cavity_h),
        (0, 0, spec.rim_z - cavity_h / 2.0),
    )
    cutters = [cavity]

    # MQ-3 airflow. The sensor needs this path to sample ambient air.
    span = (
        spec.mq3_slots * spec.mq3_slot_height
        + (spec.mq3_slots - 1) * spec.mq3_slot_gap
    )
    first_y = spec.mq3_slot_y - span / 2.0 + spec.mq3_slot_height / 2.0
    for i in range(spec.mq3_slots):
        y = first_y + i * (spec.mq3_slot_height + spec.mq3_slot_gap)
        cutters.append(
            box(
                f"MQ3 slot {i}",
                (spec.wall * 2, spec.mq3_slot_length, spec.mq3_slot_height),
                (spec.width / 2.0 - spec.wall / 2.0, y, -4.0),
            )
        )

    # MLX90614 needs an unobstructed view for an IR temperature reading.
    cutters.append(
        box(
            "MLX90614 window",
            (spec.wall * 2, spec.mlx_window, spec.mlx_window),
            (spec.width / 2.0 - spec.wall / 2.0, spec.mlx_y, -5.0),
        )
    )

    # Micro-USB access.
    cutters.append(
        box(
            "USB slot",
            (spec.wall * 2, spec.usb_width, spec.usb_height),
            (-spec.width / 2.0 + spec.wall / 2.0, spec.usb_y, -5.0),
        )
    )

    # Strap slots through both ends.
    for sign in (-1, 1):
        cutters.append(
            box(
                f"Strap slot {sign}",
                (spec.strap_slot_width, spec.wall * 2, spec.strap_slot_height),
                (0, sign * (spec.length / 2.0 - spec.wall / 2.0), spec.strap_slot_z),
            )
        )

    subtract_all(outer, cutters)
    rounded(outer, width=1.8, segments=4)
    return outer


def build_lid(spec=SPEC, shell=None):
    """The display half: OLED window, three LED holes and a display lens."""
    lid = box(
        "Shell lid",
        (spec.width, spec.length, spec.half_h),
        (0, 0, spec.half_h / 2.0),
        shell or MAT["shell"],
    )

    pocket_depth = spec.height - 5.5
    cutters = [
        # Shallow bezel step at the rim.
        box(
            "OLED bezel step",
            (spec.oled_window, spec.oled_window, 1.6),
            (spec.oled_x, spec.oled_y, spec.height - 0.8),
        ),
        # Module pocket: the display drops in and sits near the surface.
        box(
            "OLED module pocket",
            (spec.oled_window + 1.5, spec.oled_window + 1.5, pocket_depth),
            (spec.oled_x, spec.oled_y, 5.5 + pocket_depth / 2.0),
        ),
    ]
    for i in range(3):
        cutters.append(
            cylinder(
                f"LED hole {i}",
                spec.led_diameter / 2.0 + 0.4,
                spec.half_h,
                (spec.led_x + spec.led_spacing * i, spec.led_y,
                 spec.half_h / 2.0),
            )
        )

    subtract_all(lid, cutters)
    rounded(lid, width=1.4, segments=4)

    # The window is left open rather than glazed: a real module shows a tinted
    # acrylic lens, but an opaque one hides the emissive display underneath and
    # makes the face read as a dead rectangle.
    return lid, None


# ---------------------------------------------------------------------------
# internals
# ---------------------------------------------------------------------------


def build_components(spec=SPEC):
    """Electronics at real sizes, so the cavity is a genuine fit check."""
    floor = spec.floor_z
    parts = {}

    # Arduino Nano, 45 x 18 mm, lying along Y on the cavity floor.
    nano = box("Arduino Nano", (18, 45, 1.6), (-6, -10, floor + 0.8), MAT["nano"])
    rounded(nano, width=0.3, segments=2)

    headers = []
    for x in (-14.6, -5.4):
        headers.append(
            box(f"header {x}", (2.6, 15.0, 8.0), (x, -26.0, floor + 5.0),
                MAT["black_plastic"])
        )
        headers.append(
            box(f"header {x}b", (2.6, 15.0, 8.0), (x, 6.0, floor + 5.0),
                MAT["black_plastic"])
        )
    parts["nano"] = join([nano] + headers, "Arduino Nano assembly")

    # 503035 LiPo pouch cell.
    battery = box("LiPo 503035", (20, 30, 5.0), (11, -26, floor + 2.5), MAT["battery"])
    rounded(battery, width=1.2, segments=3)
    parts["battery"] = battery

    # OLED module, sitting just under the lid window.
    oled = box("OLED module", (27, 27, 4.0), (spec.oled_x, spec.oled_y, 7.6),
               MAT["pcb"])
    rounded(oled, width=0.3, segments=2)
    screen = box(
        "OLED active area",
        (21.5, 21.5, 0.5),
        (spec.oled_x, spec.oled_y, 9.7),
        MAT["screen"],
    )
    # Deliberately not joined: the emissive face needs its own material slot.
    parts["oled"] = oled
    parts["screen"] = screen

    # MQ-3 with its trimming potentiometer, facing the airflow slots.
    body = box("MQ-3 body", (13, 17, 11.0), (15, spec.mq3_slot_y, -5.2),
               MAT["black_plastic"])
    rounded(body, width=0.4, segments=2)
    pot = cylinder(
        "MQ-3 pot", 4.6, 6.0, (20.0, spec.mq3_slot_y, -2.0), (0, math.pi / 2, 0),
        mat=MAT["alu"],
    )
    parts["mq3"] = join([body, pot], "MQ-3 assembly")

    # MLX90614 on its breakout, facing the +X window.
    mlx_pcb = box("MLX90614 board", (8, 12, 1.6), (16, spec.mlx_y, -5.0), MAT["pcb"])
    can = cylinder(
        "MLX90614 can", 3.0, 3.0, (19.5, spec.mlx_y, -5.0), (0, math.pi / 2, 0),
        mat=MAT["alu"],
    )
    parts["mlx"] = join([mlx_pcb, can], "MLX90614 assembly")

    # Piezo buzzer.
    parts["buzzer"] = cylinder(
        "Buzzer", spec.led_diameter * 1.2, 9.0, (2, 34, -6.0),
        mat=MAT["black_plastic"],
    )

    # Three status LEDs, sitting under the lid holes.
    parts["leds"] = [
        sphere(
            f"LED {i}",
            spec.led_diameter / 2.0,
            (spec.led_x + spec.led_spacing * i, spec.led_y, 10.6),
            mat=MAT["led_green"],
        )
        for i in range(3)
    ]

    return parts


def build_strap(spec=SPEC):
    upper = box(
        "Strap upper",
        (spec.strap_slot_width, 48, 2.6),
        (0, spec.length / 2.0 + 23, spec.strap_slot_z),
        MAT["strap"],
    )
    rounded(upper, width=0.6, segments=2)
    lower = box(
        "Strap lower",
        (spec.strap_slot_width, 42, 2.6),
        (0, -spec.length / 2.0 - 20, spec.strap_slot_z),
        MAT["strap"],
    )
    rounded(lower, width=0.6, segments=2)
    return join([upper, lower], "Watch strap")


def build_case(spec=SPEC, seated=True, light=False):
    """Builds the whole assembly. `seated=False` lifts the lid for the
    exploded view."""
    shell = MAT["shell_light"] if light else MAT["shell"]
    tray = build_tray(spec, shell)
    lid, lens = build_lid(spec, shell)
    parts = build_components(spec)
    strap = build_strap(spec)

    if not seated:
        lift = 34.0
        lid.location.z += lift
        parts["oled"].location.z += lift * 0.55
        parts["screen"].location.z += lift * 0.55
        for led in parts["leds"]:
            led.location.z += lift * 0.55

    return {"tray": tray, "lid": lid, "strap": strap, **parts}


# ---------------------------------------------------------------------------
# renders
# ---------------------------------------------------------------------------


def _annotation(spec, text, location, rotation=(math.pi / 2.0, 0, 0), size=6.0):
    return text_object(text, text, size, location, rotation, MAT["alu"])


def render_hero(out_dir, dark=True):
    scene = reset_scene()
    build_palette()
    set_engine(scene, samples=64)
    set_resolution(scene, 1600, 1000)
    set_color_management(scene)
    build_case(light=not dark)
    # The light shell is a bright surface, so it needs less key light than the
    # dark one or it clips to flat white.
    studio(scene, dark=dark, key=1.6 if dark else 0.95,
           fill=0.6 if dark else 0.5, rim=1.3 if dark else 0.9)

    cam = camera("Camera", (185, -225, 132), (0, 2, -2), lens=68)
    name = "enclosure_hero_dark.png" if dark else "enclosure_hero_light.png"
    render_still(scene, f"{out_dir}/{name}", cam)
    return name


def render_exploded(out_dir):
    scene = reset_scene()
    build_palette()
    set_engine(scene, samples=64)
    set_resolution(scene, 1600, 1100)
    set_color_management(scene)
    build_case(seated=False)
    studio(scene, dark=True)

    cam = camera("Camera", (215, -235, 172), (0, 0, 10), lens=66)
    render_still(scene, f"{out_dir}/enclosure_exploded.png", cam)
    return "enclosure_exploded.png"


def render_orthographic(out_dir):
    """A dimensioned top view for the build documentation.

    The top view carries the two dimensions that actually matter for fitting the
    case on a strap (width across the wrist and length along the strap). Height
    is documented in hardware/README.md rather than crowded into this frame.
    """
    spec = SPEC
    scene = reset_scene()
    build_palette()
    set_engine(scene, samples=48)
    set_resolution(scene, 1600, 1100)
    set_color_management(scene)
    build_case()
    studio(scene, dark=True)

    # Dimension lines use an emissive material so they stay legible over the
    # dark shell without adding another light.
    ink = MAT["screen"]
    label_mat = material(
        "Annotation",
        color=(0.85, 0.92, 0.95, 1.0),
        emission=(0.55, 0.95, 0.92, 1.0),
        emission_strength=2.0,
    )

    top_z = spec.height + 26.0  # float the annotations clear of the case
    left_x = -spec.width / 2.0 - 22.0
    front_y = -spec.length / 2.0 - 22.0

    def rule(name, p0, p1):
        dx, dy = p1[0] - p0[0], p1[1] - p0[1]
        length = (dx * dx + dy * dy) ** 0.5
        return box(
            name,
            (length, 0.7, 0.7),
            ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, p0[2]),
            ink,
            rotation=(0, 0, math.atan2(dy, dx)),
        )

    # Width across the wrist, measured along X at the front edge.
    rule("dim width",
         (-spec.width / 2, front_y, top_z),
         (spec.width / 2, front_y, top_z))
    text_object(
        f"{spec.width:.0f} mm across wrist",
        f"{spec.width:.0f} mm across wrist",
        6.0,
        (0, front_y - 9, top_z),
        mat=label_mat,
    )

    # Length along the strap, measured along Y at the left edge.
    rule("dim length",
         (left_x, -spec.length / 2, top_z),
         (left_x, spec.length / 2, top_z))
    text_object(
        f"{spec.length:.0f} mm along strap",
        f"{spec.length:.0f} mm along strap",
        6.0,
        (left_x - 11, 0, top_z),
        rotation=(0, 0, math.pi / 2.0),
        mat=label_mat,
    )

    # Extension lines from the case corners out to each dimension line.
    for sign in (-1, 1):
        rule(f"ext x {sign}",
             (sign * spec.width / 2, -spec.length / 2, top_z),
             (sign * spec.width / 2, front_y, top_z))
        rule(f"ext y {sign}",
             (-spec.width / 2, sign * spec.length / 2, top_z),
             (left_x, sign * spec.length / 2, top_z))

    # Frame on the annotated extents rather than on the case centre, so the
    # dimension lines and labels are not clipped.
    cam = camera("Camera", (-18, -16, 400), (-18, -16, 0), ortho=175)
    cam.rotation_euler = (0.0, 0.0, 0.0)
    render_still(scene, f"{out_dir}/enclosure_dimensions.png", cam)
    return "enclosure_dimensions.png"


def main():
    out_dir = "out"
    if "--" in sys.argv:
        args = sys.argv[sys.argv.index("--") + 1:]
        if args:
            out_dir = args[0]

    os.makedirs(out_dir, exist_ok=True)

    produced = []
    produced.append(render_hero(out_dir, dark=True))
    produced.append(render_hero(out_dir, dark=False))
    produced.append(render_exploded(out_dir))
    produced.append(render_orthographic(out_dir))

    for name in produced:
        print("WROTE", name)


if __name__ == "__main__":
    main()