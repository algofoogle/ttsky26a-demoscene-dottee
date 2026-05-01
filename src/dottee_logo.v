// If LOGO_ANIM is defined, 'counter' is used to animate the drawing of the logo.
//`define LOGO_ANIM

module dottee_logo #(
  parameter START_DELAY = 240, // Don't do anything for the first 240 frames (~4 seconds) so the display has time to sync.
  parameter V_REVEAL_DELAY = 32
) (
    input clk,
    input reset,
    input [9:0] h,
    input [9:0] v,
    input [9:0] counter,
    output logo_hit
);

  localparam [9:0] CIRCLE_OUTER_TRIGGER = 10'd640;  // 'b1010000000
  localparam [9:0] CIRCLE_INNER_TRIGGER = 10'd768;  // 'b1100000000
  localparam [5:0] circle_outer_radius = 6'd63;
  localparam [5:0] circle_inner_radius = 6'd53;

  wire circle_done;
  wire circle_valid;
  wire [5:0] circle_edge;

  //NOTE: If it helps with optimisation, 1st circle_start can be as early as 'd608 ('b10_0110_0000), and 2nd can be as late as 'd768 ('b11_0000_0000).
  // ...may not make much difference using == operator anyway; they just go into simple bitwise operators?
  wire circle_outer_start = (h==CIRCLE_OUTER_TRIGGER); 
  wire circle_inner_start = (h==CIRCLE_INNER_TRIGGER);
  wire circle_start = circle_outer_start || circle_inner_start;
`ifdef LOGO_ANIM
  wire [9:0] counter_delayed = (counter<START_DELAY) ? 0 : counter-START_DELAY;
  wire grow_limit = (counter_delayed>=53);
  wire [5:0] circle_radius =
    (h >= CIRCLE_INNER_TRIGGER) ? (grow_limit ? circle_inner_radius : counter_delayed) // Animated inner radius.
                                : circle_outer_radius;
`else
  wire [5:0] circle_radius =
    (h >= CIRCLE_INNER_TRIGGER) ? circle_inner_radius
                                : circle_outer_radius;
`endif//LOGO_ANIM

  reg [5:0] circle_outer_edge; // Stores outer edge before circle_edge starts to compute the inner edge.

  wire [9:0] cvo = v-112; // Circle vertical offset: Logo positioning.

  circle_edge slow_circle(
    // Inputs:
    .clk(clk),
    .reset(reset),
    .radius(circle_radius),
    .vertical_line(cvo[6] ? cvo[5:0] : ~cvo[5:0]), // Circle is vertically symmetrical.
    .start(circle_start),
    // Outputs:
    .done(circle_done),
    .valid(circle_valid),
    .edge_point(circle_edge)
  );

  always @(posedge clk) begin
    if (reset)
      circle_outer_edge <= 0;
    else if (h==10'd700)
      circle_outer_edge <= circle_edge;
  end

`ifdef LOGO_ANIM
  // Vertical reveal counter:
  wire [9:0] vrc = {counter_delayed[8:0],1'b0};

  // Wipe-reveal logo details up and down from middle:
  wire vertical_reveal = vrc>10'd128 || ( // Fully revealed when the counter is over the limit.
    vrc>V_REVEAL_DELAY &&                 // Start time reached.
    cvo>(10'd128+V_REVEAL_DELAY-vrc) &&   // Top reveal.
    cvo<(10'd128-V_REVEAL_DELAY+vrc)      // Bottom reveal.
  );
`else
  wire vertical_reveal = 1;
`endif//LOGO_ANIM

  // Circle horizontal offset (actually, just flips misaligned hemispheres):
  wire [9:0] cho = h^64;

  // Circle horizontal hemisphere fill with mirror (to make a full circle).
  //NOTE: This repeats on X
  wire [5:0] circle_scan = cho[6] ? cho[5:0] : ~cho[5:0];

  // Within (or out) of circles?
  wire in_outer_circle = (circle_scan > circle_outer_edge);
  wire in_inner_circle = (circle_scan > circle_edge);

  // Is our vertical position within any parts of the logo?
  // Could also be expressed with "<" and ">", but this seems optimal? Yosys may disagree.
  wire logo_upper_half = (cvo[9:6] == 4'd1);
  wire logo_lower_half = (cvo[9:6] == 4'd2);

  // Are we within the ring region (the border between bigger and smaller concentric circles),
  // but also clipping the bottom hook region of the first (non-truncated) "e":
  wire in_circle = circle_valid && in_outer_circle && !in_inner_circle;

`ifdef LOGO_ANIM
  // Animated clipping of the left/right sides of the logo (to make "D" and truncated "e"):
  wire side_clip = ((h>counter_delayed) && (h<(640-counter_delayed))) || ((h>=32) && (h<(640-32)));
`else
  wire side_clip = ((h>=32) && (h<(640-32)));
`endif//LOGO_ANIM

  // Are we in the main rectangle of the logo (checked to avoid tiling):
  wire in_logo = (logo_upper_half || logo_lower_half) && side_clip;

  // Are we in specifically the cell where the TT logo is rendered?
  wire in_tt_logo = (h[9:8]==2'b01);

  // Top/bottom clipping for vertical bar(s) on D and final "e":
  //NOTE: Would >=72 or >=76 (for example) be better? Fewer bits to compare?
  // Could even just check cvo[7:3] if >=72 works.
  // Another option: v>=(74+112) && v<(184+112)??
  //CHEAT: Just clip to in_outer_circle!!
  wire vertical_bar_clip = (cvo>74 && cvo<182); // >64+10, <192-10

  wire inclusions = vertical_reveal && (
    (h<42 && vertical_bar_clip) || // "D" left bar. Would <=42 be more efficient?
    (h>=598 && vertical_bar_clip && logo_upper_half) || // Final E top-right bar.
    (
        // "TT" inner:
        //NOTE: Instead of constraining the rectangles' left/bottom, just clip with in_outer_circle.
        //NOTE: We could get away with fudging 1 pixel to prefer even-numbered comparisons, if it saves 1 bit here and there.
        //NOTE: We shold be able to simplify the bit ranges of 'h' checks by using in_tt_logo?
        (
          (cvo>(64+27) && cvo<=(64+44)           && h<332 && in_tt_logo ) ||  // Upper bar; clipped by circle.
          (cvo>(64+58) && cvo< (64+76)  && h>300 && h<361               ) ||  // Lower bar.
          (cvo>(64+27) && cvo<=(64+87)  && h>293 && h<313               ) ||  // Upper post.
          (cvo>(64+58)                  && h>323 && h<343 && in_tt_logo )     // Lower post; clipped by circle. //SMELL: Don't need in_tt_logo here?
        ) && in_outer_circle
    )
  );
  wire exclusions = vertical_reveal && (
      // Gaps in TT ring:
      ( in_tt_logo && h<276 && cvo>(64+44) && cvo<(64+52) ) ||
      (      h>342 && h<349 && cvo>(64+100)) ||
      (h[9:5]==15 && logo_lower_half)
  );
  // 'overlaid' is an exception to 'exclusions':
  //NOTE: Could clip this to in_outer_circle?
  wire overlaid = vertical_reveal && (cvo>123 && cvo<133 && cho[9:7]>=3); // Middle bar for both "e"s.

  assign logo_hit = in_logo && ((in_circle || inclusions) && ~exclusions || overlaid);

endmodule
