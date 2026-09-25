// ============================================================================
// August <-> UniFi Door Monitor — Pi Zero W + 2-Channel Relay Enclosure
// ----------------------------------------------------------------------------
// Parametric OpenSCAD model for a snap/friction-fit project box that houses:
//   - a Raspberry Pi Zero W (mounted on standoffs, port side facing one end wall)
//   - a 2-channel opto-isolated relay module (e.g. SunFounder B00E0NTPP4)
//
// Render/export:
//   openscad -o base.stl -D 'part="base"' enclosure.scad
//   openscad -o lid.stl  -D 'part="lid"'  enclosure.scad
// Or open in the OpenSCAD GUI and use the `part` variable below / F5 preview.
//
// IMPORTANT — verify before printing:
//   Pi Zero W board outline + mounting-hole spacing are taken from the official
//   Raspberry Pi Foundation mechanical drawing (RPI-ZERO-V1_2) and can be
//   trusted as-is. The relay module's exact hole spacing (varies slightly
//   between hardware batches) and the Pi's port-cutout positions (not
//   dimensioned in that drawing) are still best-effort — print the base only
//   first, test-fit your actual hardware, then adjust and reprint. See
//   ../../docs/enclosure.md for the recommended print-test-adjust workflow.
// ============================================================================

part = "both"; // "base", "lid", or "both" (both = side-by-side preview/render)

// ---- General fit tolerances -------------------------------------------------
wall            = 2.2;   // outer wall thickness
floor_t         = 2.2;   // floor thickness
lid_t           = 2.2;   // lid plate thickness
fit_clearance   = 0.25;  // general FDM clearance between mating parts
lip_depth       = 3.0;   // depth of the lid's friction-fit skirt
lip_gap         = 1.3;   // wall material removed at the top step for the lid skirt
corner_r        = 3.0;   // outer corner rounding radius

// ---- Raspberry Pi Zero W -----------------------------------------------------
// Board outline + mounting holes verified against the official Raspberry Pi
// Foundation mechanical drawing (RPI-ZERO-V1_2, Mike Stimson/James Adams,
// 23/09/2015): https://github.com/ikorb/raspi-documentation/blob/master/hardware/raspberrypi/mechanical/Raspberry-Pi-Zero-V1.2-Mechanical.pdf
// Board: 65 x 30mm, corner radius 3.0mm. 4x M2.5 holes drilled to dia 2.75mm
// +/-0.05mm, each inset 3.5mm from its nearest edge in both X and Y (giving
// 58mm x 23mm hole-to-hole spacing). Pi Zero W shares this same PCB outline.
pi_len          = 65;    // board length (mm), along the port edge
pi_wid          = 30;    // board width (mm)
pi_standoff_h   = 3.0;   // standoff height under the board (clears bottom-side solder)
pi_hole_d       = 2.9;   // clearance hole for M2.5 self-tapping screw (board hole is dia 2.75mm)
pi_hole_inset_x = 3.5;   // hole center inset from short edges (per official drawing)
pi_hole_inset_y = 3.5;   // hole center inset from long edges (per official drawing)
pi_zone_pad     = 4;     // clearance around the Pi footprint inside the case

// Port cutout on the Pi's port-side edge (mini HDMI + 2x micro-USB: OTG/data
// and PWR IN). On the real board these three connectors run along one LONG
// (65mm) edge of the Pi — NOT a short edge — and Raspberry Pi has never
// published an official mechanical drawing with exact connector positions
// (only the board outline + mounting holes are documented, see note above).
// Rather than guess three precise per-connector windows and risk them being
// wrong for your exact board revision, this cuts ONE generous continuous
// slot spanning the whole connector cluster — the common, print-forgiving
// approach used by most Pi Zero enclosures. See docs/enclosure.md.
pi_port_slot_x0  = 4;                    // slot start, from the Pi board's left edge (mm)
pi_port_slot_x1  = 61;                   // slot end, from the Pi board's left edge (mm)
pi_port_slot_h   = 9;                    // slot height (mm) — clears HDMI + both micro-USB bodies
pi_port_slot_zlo = pi_standoff_h;        // slot bottom Z, right at the board's top surface

// ---- 2-Channel Relay Module (e.g. SunFounder, ~50.5 x 38.5 x 18.5mm) --------
relay_len         = 50.5;
relay_wid         = 38.5;
relay_height      = 18.5;  // tallest point above its own PCB underside
relay_standoff_h  = 3.0;
relay_hole_d      = 3.4;   // clearance hole for M3 screw (board holes ~3.1mm)
relay_hole_inset  = 3.0;   // hole center inset from each edge (approx — verify)
relay_zone_pad    = 4;

// Wire exit slot for the 4 dry-contact leads (DPS +/-, AUX +/-) leaving the case
wire_slot_w = 14;
wire_slot_h = 6;

// ---- Layout: Pi zone | wire channel | Relay zone, side by side -------------
gap_between_zones = 8;

pi_zone_w    = pi_len + 2*pi_zone_pad;
pi_zone_d    = pi_wid + 2*pi_zone_pad;
relay_zone_w = relay_len + 2*relay_zone_pad;
relay_zone_d = relay_wid + 2*relay_zone_pad;

inner_w = pi_zone_w + gap_between_zones + relay_zone_w;
inner_d = max(pi_zone_d, relay_zone_d);

outer_w = inner_w + 2*wall;
outer_d = inner_d + 2*wall;

// Case wall height: clear the tallest component (relay module) plus its
// standoff, plus headroom for wiring looped above it.
inner_h  = relay_standoff_h + relay_height + 6;
wall_h   = inner_h + floor_t;

// ============================================================================
// Helpers
// ============================================================================

module rounded_rect(w, d, r) {
  hull() {
    for (x = [r, w - r])
      for (y = [r, d - r])
        translate([x, y, 0]) circle(r = r, $fn = 48);
  }
}

module standoff(h, hole_d, outer_d = 6) {
  difference() {
    cylinder(h = h, d = outer_d, $fn = 32);
    translate([0, 0, -0.5]) cylinder(h = h + 1, d = hole_d, $fn = 24);
  }
}

// ============================================================================
// Base
// ============================================================================

module base() {
  pi_origin = [wall + pi_zone_pad, wall + (inner_d - pi_wid)/2];

  difference() {
    union() {
      // Outer shell
      linear_extrude(height = wall_h)
        rounded_rect(outer_w, outer_d, corner_r);
    }

    // Hollow out interior, leaving `wall` thickness on the sides and
    // `floor_t` on the bottom.
    translate([wall, wall, floor_t])
      linear_extrude(height = wall_h)
        rounded_rect(inner_w, inner_d, max(corner_r - wall, 0.1));

    // Recessed step at the top of the walls so the lid's skirt seats flush.
    translate([wall - lip_gap, wall - lip_gap, wall_h - lip_depth])
      linear_extrude(height = lip_depth + 1)
        rounded_rect(inner_w + 2*lip_gap, inner_d + 2*lip_gap, max(corner_r - wall + lip_gap, 0.1));

    // --- Port cutout on the Pi's port-side wall (y = 0 face) ---
    // A single continuous slot spanning the mini HDMI + 2x micro-USB
    // connector cluster, positioned along the Pi's LONG (65mm) edge — see
    // the pi_port_slot_* comments above for why this isn't 3 separate
    // precisely-positioned windows.
    translate([pi_origin[0] + pi_port_slot_x0, -1, pi_port_slot_zlo])
      cube([pi_port_slot_x1 - pi_port_slot_x0, wall + 2, pi_port_slot_h]);

    // --- Wire exit slot on the relay end wall (x = outer_w face) ---
    translate([outer_w - wall - 1, wall + inner_d/2 - wire_slot_w/2, floor_t + 2])
      cube([wall + 2, wire_slot_w, wire_slot_h]);

    // --- Optional second wire slot on the back long wall for the physical
    //     door-sensor cross-check lead (see docs/wiring-diagram.md) ---
    translate([wall + inner_w/2 - wire_slot_w/2, outer_d - wall - 1, floor_t + 2])
      cube([wire_slot_w, wall + 2, wire_slot_h]);
  }

  // --- Pi Zero W standoffs ---
  for (dx = [pi_hole_inset_x, pi_len - pi_hole_inset_x])
    for (dy = [pi_hole_inset_y, pi_wid - pi_hole_inset_y])
      translate([pi_origin[0] + dx, pi_origin[1] + dy, floor_t])
        standoff(pi_standoff_h, pi_hole_d);

  // --- Relay module standoffs ---
  relay_origin = [wall + pi_zone_w + gap_between_zones + relay_zone_pad,
                   wall + (inner_d - relay_wid)/2];
  for (dx = [relay_hole_inset, relay_len - relay_hole_inset])
    for (dy = [relay_hole_inset, relay_wid - relay_hole_inset])
      translate([relay_origin[0] + dx, relay_origin[1] + dy, floor_t])
        standoff(relay_standoff_h, relay_hole_d);
}

// ============================================================================
// Lid
// ============================================================================

// Local Z convention for this module: z=0 is the tip of the skirt (the part
// that reaches deepest into the base's recess); the flat top plate sits above
// it, from z=lip_depth to z=lip_depth+lid_t. Keeping everything at z>=0 avoids
// negative-Z geometry, which some slicers mishandle.
module lid() {
  relay_center_x = wall + pi_zone_w + gap_between_zones + relay_zone_w/2;

  difference() {
    union() {
      // Downward friction-fit skirt that plugs into the base's recessed step
      translate([wall - lip_gap + fit_clearance, wall - lip_gap + fit_clearance, 0])
        linear_extrude(height = lip_depth)
          difference() {
            rounded_rect(inner_w + 2*lip_gap - 2*fit_clearance, inner_d + 2*lip_gap - 2*fit_clearance, max(corner_r - wall + lip_gap, 0.1));
            offset(delta = -1.6)
              rounded_rect(inner_w + 2*lip_gap - 2*fit_clearance, inner_d + 2*lip_gap - 2*fit_clearance, max(corner_r - wall + lip_gap, 0.1));
          }

      // Top plate, flush with the base's outer footprint, sitting on top of the skirt
      translate([0, 0, lip_depth])
        linear_extrude(height = lid_t)
          rounded_rect(outer_w, outer_d, corner_r);
    }

    // Ventilation slits over the relay's footprint (it's the one part that
    // gets faintly warm) — cut fully through the top plate.
    for (i = [-2, -1, 0, 1, 2])
      translate([relay_center_x + i*6 - 1, wall + 4, lip_depth - 0.5])
        cube([2, inner_d - 8, lid_t + 1]);
  }
}

module thumb_notch() {
  translate([outer_w/2, outer_d, wall_h/2])
    rotate([90, 0, 0])
      cylinder(h = 6, r = 6, $fn = 32);
}

// ============================================================================
// Render selection
// ============================================================================

if (part == "base") {
  difference() {
    base();
    thumb_notch();
  }
} else if (part == "lid") {
  lid();
} else {
  difference() {
    base();
    thumb_notch();
  }
  translate([outer_w + 15, 0, 0])
    lid();
}
