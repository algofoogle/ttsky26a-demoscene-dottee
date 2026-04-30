module dottee_logo #(
  parameter START_DELAY = 240, // Don't do anything for the first 240 frames (~4 seconds) so the display has time to sync.
  parameter V_REVEAL_DELAY = 50
) (
    input clk,
    input reset,
    input [9:0] h,
    input [9:0] v,
    input [9:0] counter,
    output logo_hit
);

  wire circle_done;
  wire circle_valid;
  wire [5:0] circle_edge;

  wire circle_inner_start = h==10'd704;
  wire circle_start = (h==10'd640 || circle_inner_start);
  wire [9:0] counter_delayed = (counter<START_DELAY) ? 0 : counter-START_DELAY;
  wire grow_limit = (counter_delayed>=53);
  wire [5:0] circle_radius =
    (h >= 10'd704)  ? (grow_limit ? 6'd53 : counter_delayed)
                    : 6'd63; // Inner vs. outer radius.

  reg [5:0] circle_outer_edge;

  wire [9:0] cvo = v-112; 

  circle_edge slow_circle(
    .clk(clk),
    .reset(reset),
    .radius(circle_radius),
    .vertical_line(cvo[6] ? cvo[5:0] : ~cvo[5:0]),
    .start(circle_start),
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

  // Wipe-reveal logo details up and down from middle:
  wire vertical_reveal = (counter_delayed>V_REVEAL_DELAY && cvo>(128-counter_delayed+V_REVEAL_DELAY) && cvo<(128+counter_delayed-V_REVEAL_DELAY)) || counter_delayed>128;

  // Circle horizontal offset:
  wire [9:0] cho = h^64;

  // Circle horizontal hemisphere fill with mirror (to make a full circle):
  wire [5:0] circle_scan = cho[6] ? cho[5:0] : ~cho[5:0];

  // Within (or out) of circles?
  wire in_outer_circle = (circle_scan > circle_outer_edge);
  wire in_inner_circle = (circle_scan > circle_edge);

  // Is our vertical position within any parts of the logo?
  wire logo_upper_half = (cvo[9:6] == 4'd1);
  wire logo_lower_half = (cvo[9:6] == 4'd2);

  // Are we within the ring region (the border between bigger and smaller concentric circles),
  // but also clipping the bottom hook region of the first (non-truncated) "e":
  wire in_circle = circle_valid && in_outer_circle && !in_inner_circle;

  // Animated clipping of the left/right sides of the logo (to make "D" and truncated "e"):
  wire side_clip = ((h>counter_delayed) && (h<(640-counter_delayed))) || ((h>32) && (h<(640-32)));

  // Are we in the main rectangle of the logo (checked to avoid tiling):
  wire in_logo = (logo_upper_half || logo_lower_half) && side_clip;

  // Are we in specifically the cell where the TT logo is rendered?
  wire in_tt_logo = (h[9:8]==2'b01);

  // Top/bottom clipping for vertical bar(s) on D and final "e":
  wire vertical_bar_clip = (cvo>74 && cvo<182);

  wire inclusions = vertical_reveal && (
    (h<42 && vertical_bar_clip) || // "D" left bar.
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
          (cvo>(64+58)                  && h>323 && h<343 && in_tt_logo )     // Lower post; clipped by circle.
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
  wire overlaid = vertical_reveal && (cvo>123 && cvo<133 && cho[9:7]>=3); // Middle bar for both "e"s.

  assign logo_hit = in_logo && ((in_circle || inclusions) && ~exclusions || overlaid);

endmodule
