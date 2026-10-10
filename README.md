# Smart Safety Ecosystem

A Flutter desktop and mobile console for the **LoRa-Based Accident Alert and
Portable Wearable Risk Screening System**.

The application brings two independent safety subsystems into one interface:
a vehicle node that detects a possible collision or rollover and transmits a
compact alert over LoRa, and a portable wristband that performs preliminary
alcohol-exposure and temperature screening with on-device classification.

---

## Scope and honesty statement

This project implements the architecture described in
`PP Hackthon/Presentation-Companion-Notes.md`. Read this before treating any
number in the app as validated:

- **No measured accuracy or response-time figures are reported anywhere.** Every
  performance field is unvalidated, and the app says so in Settings → *Scope and
  limitations*.
- **AWTRA is rule-based threshold logic**, not a trained machine-learning model.
  The bands (0–39 safe, 40–79 medium risk, ≥80 high risk) are prototype
  calibration values that require validation.
- **Detection thresholds are preliminary**, not universal crash-detection
  standards. They must be calibrated per vehicle before any field use.
- **Wearable screening is preliminary.** The MQ-3 responds to gases other than
  alcohol vapour and the MLX90614 depends on distance and ambient conditions.
  A positive reading is an indication to follow up, never proof, and it never
  implies that anyone caused an accident.
- **LoRa never contacts a hospital.** LoRa is only the radio link; the gateway
  and backend perform routing, facility lookup and notification.
- **Real Hardware Mode has no device attached in this repository.** It reports
  every transmission as failed rather than substituting simulated data. See
  [Real Hardware Mode](#real-hardware-mode).

---

## Running it

```bash
flutter pub get
flutter run -d linux      # desktop
flutter test              # 90 tests
flutter analyze           # clean
flutter build linux --release
```

Supported targets: Linux, Windows, macOS, Android.

---

## Architecture

```
lib/
  main.dart                     entry point; loads settings + log before first frame
  core/design/                  design system: tokens, palette, theme
  domain/                       pure logic, no Flutter UI imports
    models/                     incident, IMU, GPS, LoRa packet, severity
    awtra.dart                  AWTRA risk classification
    accident_detector.dart      detection state machine
    moving_average.dart         bounded ring-buffer filter
    hardware/                   transport interface + honest unavailable impl
    simulation/                 deterministic scenarios + playback engine
  data/                         settings and incident persistence
  state/                        AppController, telemetry series
  ui/
    shell/                      adaptive navigation (sidebar / rail / bottom bar)
    components/                 reusable themed widgets
    screens/                    the seven destinations plus secondary pages
```

### Layering rule

`domain/` is pure Dart with no I/O and no Flutter dependency. The accident
detector is a deterministic state machine driven by two inputs — `ingest(sample)`
and `advance(now)`. That is what makes Demo Mode and Real Hardware Mode share
exactly the same detection code instead of running two implementations.

### Dependencies

Deliberately minimal:

| Package | Why |
| --- | --- |
| `shared_preferences` | Theme, mode and settings persistence |
| `path_provider` | Writable location for the incident log |

There is **no charting library** (telemetry is hand-painted with
`CustomPainter`), **no 3D engine** (depth is painted vector work), and **no state
management package** (`ChangeNotifier` + `ListenableBuilder` + one
`InheritedWidget` for navigation). Every dependency carries a concrete
requirement; nothing was added for convenience.

SQLite is deliberately not used: it has no Linux, Windows or macOS
implementation, and incident history must persist on every target. Records are
held in memory and flushed as a JSON document via a write-temp-then-rename, so a
crash mid-write cannot truncate the log.

---

## Modes

### Demo Mode (default)

- Runs entirely offline: no device, radio, gateway or network.
- Scenarios are **deterministic and repeatable** — the same scenario always
  produces the same samples, event and outcome.
- Playback supports play, pause, reset and 0.25×–4× speed.
- Cannot send a real notification under any circumstance.
- Every record is stamped `Simulated` and rendered with a distinct badge.

Built-in scenarios cover the documented alternate paths:

| Scenario | What it demonstrates |
| --- | --- |
| Rear-end collision | Full detect → confirm → cancel → GPS → LoRa flow |
| Harsh bump | Candidate that falls back below threshold; nothing is sent |
| Vehicle rollover | Tilt and rotation thresholds |
| Impact with no GPS fix | Alert still transmitted, flagged as position-unavailable |
| Impact with no gateway | Sent but unacknowledged — never reported as delivered |
| Normal driving | Stays below every threshold; no alert |

### Real Hardware Mode

Switching to it always requires confirmation. It uses the
`PacketTransport` interface, and the bundled implementation
(`UnavailablePacketTransport`) is deliberately honest: with no radio attached it
returns `noGatewayInRange` for **every** attempt. It never reports a success it
cannot verify.

To attach real hardware, implement `PacketTransport` (and optionally
`ImuSource` / `GpsSource`) in `lib/domain/hardware/` and change the single
transport construction in `lib/state/app_controller.dart`. Nothing else in the
application knows the difference.

**Attempts and acknowledgements are tracked and displayed separately.** A packet
that was sent but never confirmed is shown as *Unconfirmed*, never as delivered.

---

## Interface design

### Adaptive layout

Layout class comes from available width only — never from `Platform.isAndroid`
and friends — so a resized desktop window and a rotated tablet both reflow:

| Width | Navigation | Dashboard |
| --- | --- | --- |
| `< 600` | Bottom bar | Single column |
| `600–1000` | Bottom bar | Single column, paired cards |
| `1000–1360` | Collapsed icon rail | Single column, paired cards |
| `≥ 1360` | Full labelled sidebar | Two-column |

One `AppShell` and one route set serve every form factor; there is no duplicated
desktop/mobile interface.

### Themes

Light, Dark and System, with **Light as the first-launch default**, persisted
across restarts and applied before the first paint. Widgets read semantic tokens
from a `SseColors` theme extension rather than hard-coding colours, so a single
widget implementation renders correctly in both palettes.

The dark theme is an original graphite/charcoal system (not CRED branding): the
window background is `#0B0D10` rather than pure black so elevation reads as
luminance, and depth comes from a 1px metallic top edge plus a soft ambient
shadow rather than glow or blur.

### Progressive disclosure

Ordinary use shows only what matters: mode, device status, connectivity, recent
incidents, latest valid position, and one primary action.

Threshold editors, raw streams, AWTRA weight tuning, packet inspection and
database controls sit behind an **Advanced toggle** that is itself behind a
confirmation dialog, and edits are paired with their consequences.

**Critical warnings and connection failures are never hidden behind the
advanced toggle.**

### Accessibility

- Colour is never the sole carrier of meaning: Demo/Real mode uses an icon *and*
  a word (*Simulated* / *Live*), and every severity badge carries a label.
- Text scaling is clamped to 0.85×–1.6× and the layout is verified at 1.6×.
- Touch targets are at least 48 logical pixels.
- Animations are 150–300 ms with standard easing — no bounce or elastic motion —
  and respect `disableAnimations`.

---

## Verification

```
flutter analyze   →  No issues found
flutter test      →  90 tests, all passing
flutter build linux --release →  ✓ Built
```

Test coverage:

- **Domain (47 tests)** — moving average, AWTRA bands and masking behaviour,
  the full detection state machine, cancellation, no-GPS and no-gateway paths,
  attempt/acknowledgement separation, and scenario determinism.
- **Application (19 tests)** — Light-by-default, persistence of theme and mode,
  breakpoint mapping, navigation, live theme switching, non-colour mode
  indicators, incident store round-trip.
- **Responsive (24 tests)** — every screen at 360 / 414 / 600 / 768 / 1000 /
  1280 / 1600 / 1920 px, in both themes, plus every screen at 1.6× text scale.
  A failure reports the text inside the overflowing subtree so it points at the
  widget rather than a pixel count.

The AWTRA and detector tests were written before the UI and caught three real
defects: a temperature ramp that scored the entire physiologically normal range
as risky, an alcohol weight that made a High-risk screening result
unreachable, and a detector that could never be re-armed after dispatching an
alert.

---

## Known limitations

- **No real hardware is connected.** Real Hardware Mode is implemented and
  honest, but unverified against a device.
- **No serial or TCP adapter is wired up** — only the interface and the
  truthful unavailable implementation.
- **External notifications are not implemented.** The authorisation flag and its
  consent flow exist and are disabled by default, but no dispatch backend is
  connected.
- **The map panel is schematic**, showing coordinates with a marker rather than
  real map tiles, which would require a heavy dependency and a network call.
- **Firmware is not part of this repository.**
- Incident log is capped at 500 records, dropping the oldest on write.