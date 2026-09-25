# 3D Printable Enclosure

A parametric OpenSCAD model that houses the Raspberry Pi Zero W and the 2-channel relay
module side-by-side in one printed box, sized to fit the [`SunFounder 2-Channel
Relay Module`](https://www.amazon.com/dp/B00E0NTPP4) referenced in this project's BOM.

File: [`hardware/enclosure/enclosure.scad`](../hardware/enclosure/enclosure.scad)

## Overview

- **Footprint:** ~144 x 51 mm
- **Height:** ~30mm base + 2.2mm lid ≈ 32mm assembled
- **Two zones, side by side:** Pi Zero W on standoffs on one end, relay module on standoffs on
  the other, with an open channel between them for jumper wires.
- **Lid:** friction-fit (no screws) — a recessed step in the base walls accepts a skirt
  molded onto the underside of the lid. No supports needed for either part.
- **Cutouts:**
  - Three port openings on the Pi's end wall (mini HDMI / USB / micro-USB power)
  - A wire-exit slot on the relay's end wall for the four DPS/AUX dry-contact leads
    heading to the UA Hub Door Mini
  - A second wire slot on the back wall for the optional physical door-sensor cross-check lead
  - Ventilation slits in the lid over the relay's footprint (it runs faintly warm under load)
  - A thumb notch cut into the back wall so you can pop the lid off without a tool

## Print settings (FDM, PLA or PETG)

| Setting | Value |
|---|---|
| Layer height | 0.2 mm |
| Perimeters/walls | 3 |
| Infill | 15–20% |
| Supports | None required |
| Orientation | Print both parts flat, largest face down |

## Recommended workflow: print → test-fit → adjust

The board hole positions and port-cutout locations in the model are best-effort from public
reference dimensions, **not** a caliper measurement of your exact board revisions — SunFounder
relay boards in particular vary slightly between hardware batches. Don't commit to a full
production print before checking fit:

1. Render/export just the base: `openscad -o base.stl -D 'part="base"' enclosure.scad`
2. Print the base only.
3. Test-fit your actual Pi Zero W and relay module on the standoffs, and check the port cutouts
   line up well enough for your cables/connectors.
4. Adjust the parameters at the top of `enclosure.scad` (standoff hole insets, port cutout
   positions/widths, relay hole inset) to match what you measured.
5. Re-render and print the base again, then export/print the lid:
   `openscad -o lid.stl -D 'part="lid"' enclosure.scad`
6. Test the lid's friction fit. If it's too tight/loose, tweak `fit_clearance` (default 0.25mm)
   and reprint just the lid.

## Assembly

1. Screw the Pi Zero W onto its standoffs with M2.5 self-tapping screws (or M2.5 machine screws
   if you tapped the standoff holes).
2. Screw the relay module onto its standoffs with M3 self-tapping screws.
3. Wire the Pi's GPIO to the relay module's VCC/GND/IN1/IN2 per
   [`../docs/wiring-diagram.md`](../docs/wiring-diagram.md), routing the jumpers through the
   open channel between the two zones.
4. Feed the relay's four dry-contact leads (DPS +/-, AUX +/-) out through the wire-exit slot to
   the UA Hub Door Mini's terminal block.
5. Power the Pi via the micro-USB power cutout.
6. Snap the lid on.

## Customizing

All key dimensions are parameters at the top of the `.scad` file — relay board size/hole
spacing, Pi standoff positions, wall thickness, wire slot sizes, and fit tolerances. If you're
using a different relay board (e.g. a SparkFun Qwiic relay or a 4-channel board), update
`relay_len`/`relay_wid`/`relay_height`/`relay_hole_inset` accordingly rather than starting a new
model from scratch.
