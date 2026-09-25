# Wiring Diagram — Raspberry Pi Zero W → Relay Module → UA Hub Door Mini

## Bill of materials

| Qty | Item | Notes |
|----:|------|-------|
| 1 | Raspberry Pi Zero W (or Zero 2 W) | Runs `monitor.py`, needs Wi-Fi for August cloud API |
| 1 | 2-channel 3.3V/5V logic-level relay module | e.g. SRD-05VDC-SL-C style board with **opto-isolated** inputs. 2 channels = DPS + AUX |
| 1 | 2×20 GPIO header (or pre-soldered Pi Zero W) | For jumper wire connection |
| 4 | F-F or M-F jumper wires | Pi GPIO/5V/GND → relay board |
| 2 | 2-conductor low-voltage wire runs (18–22 AWG) | Relay dry-contact terminals → UA Hub Door Mini DPS/AUX terminals |
| 1 | 5V/2A micro-USB (or PoE HAT) power supply | Powers the Pi independently of the hub |
| Optional | Physical magnetic reed switch | If you also want a *real* door contact sensor as a cross-check input on a spare Pi GPIO pin (see [Optional: real sensor input](#optional-real-sensor-cross-check)) |

> The relay module needs its own logic power. Most cheap boards run their relay coils off 5V and
> accept 3.3V-tolerant trigger signals via opto-isolators — confirm your specific board's trigger
> voltage before wiring to the Pi's GPIO (which is 3.3V logic, **not 5V tolerant**).

## UA Hub Door Mini terminal reference

Per Ubiquiti's official wiring guidance, the hub's low-voltage terminal block exposes these
**dry-contact** (no continuous voltage/current sourced by the Pi side) inputs/outputs:

| Terminal | Type | Purpose |
|---|---|---|
| `DPS +` / `DPS −` | Dry contact input | Door Position Sensor (open/closed) |
| `REX +` / `REX −` | Dry contact input | Request-to-Exit button/PIR |
| `AUX +` / `AUX −` | Dry contact input | Auxiliary/general purpose input |
| Relay `NO` / `COM` / `NC` | Dry contact output | Drives the electric strike/maglock (not used in this project — lock control stays with August) |
| 12V DC barrel / PoE+ | Power in | Powers the hub itself |

This project only touches **DPS** and **AUX** — we are *reporting* state into the hub, not
controlling the door strike.

## Connection diagram

```
 Raspberry Pi Zero W                 2-Channel Relay Module              UA Hub Door Mini
┌─────────────────────┐            ┌─────────────────────────┐        ┌─────────────────────┐
│                      │            │                         │        │                     │
│   5V (pin 2) ────────┼───────────►│ VCC                     │        │                     │
│   GND (pin 6) ────────┼───────────►│ GND                     │        │                     │
│                      │            │                         │        │                     │
│  GPIO17 (pin 11) ─────┼───────────►│ IN1  (DPS relay coil)   │        │                     │
│  GPIO27 (pin 13) ─────┼───────────►│ IN2  (AUX relay coil)   │        │                     │
│                      │            │                         │        │                     │
│                      │            │  CH1  COM ──────────────┼────────►  DPS +              │
│                      │            │  CH1  NO  ───────────────┼────────►  DPS −              │
│                      │            │                         │        │                     │
│                      │            │  CH2  COM ──────────────┼────────►  AUX +              │
│                      │            │  CH2  NO  ───────────────┼────────►  AUX −              │
└─────────────────────┘            └─────────────────────────┘        └─────────────────────┘
```

Wire each relay channel's **NO (Normally Open) + COM** pair across the corresponding hub
terminal pair. When `monitor.py` drives a GPIO pin LOW/HIGH (per your relay board's active level),
the relay coil energizes and closes NO↔COM, presenting a momentary/held short across the hub's
input — electrically identical to a reed switch closing or a button being pressed.

### Logic mapping (default, configurable in `config.yaml`)

| August state | DPS relay (CH1) | AUX relay (CH2) |
|---|---|---|
| Door closed | Closed (contact made) | — |
| Door open | Open (contact broken) | — |
| Lock: locked | — | Closed (contact made) |
| Lock: unlocked | — | Open (contact broken) |

Most reed switches are wired **normally closed when the magnet is present (door closed)** —
match this polarity in the UniFi Access app's DPS configuration (there's an "invert sense" toggle
if your wiring ends up backwards; easier to fix in software than to re-wire).

## Power and grounding notes

- **Do not** share the Pi's GND with the hub's terminal block directly *except* through the relay
  module's isolated contact side — the whole point of the relay is to keep the Pi's 3.3V domain
  and the hub's sensing circuit galvanically separate.
- Power the Pi from its own 5V supply (or PoE HAT if you have one), not from the hub's 12V/PoE+
  input — the hub's power budget is for the hub + connected lock hardware, not extra compute.
- Keep low-voltage sensor runs away from AC power/electric strike wiring to avoid induced noise
  toggling the relay unexpectedly.

## Optional: real sensor cross-check

If you want a physical safety net that doesn't depend on the August cloud API being reachable,
wire a magnetic reed switch directly to a spare Pi GPIO (e.g. BCM `4`) with a pull-up resistor
(`gpiozero.Button(4, pull_up=True)`), and have `monitor.py` compare that ground-truth reading
against the August Doorsense value, logging/alerting on mismatch instead of blindly trusting the
cloud state.

## References

- Ubiquiti: [Wiring a Door Position Sensor to the UniFi Access Control Hub](https://help.ui.com/hc/en-us/articles/25795833795223-Wiring-a-Door-Position-Sensor-to-the-UniFi-Access-Control-Hub)
- Ubiquiti: [UA Hub Door Mini Quick Start Guide](https://dl.ui.com/qig/ua-hub-door-mini/)
- Ubiquiti tech specs: <https://techspecs.ui.com/unifi/door-access/ua-hub-door-mini>
