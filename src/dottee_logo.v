module dottee_logo(
    input clk,
    input reset,
    input [9:0] h,
    input [9:0] v,
    output logo_hit
);

  wire circle_done;
  wire circle_valid;
  wire [5:0] circle_edge;

  wire circle_inner_start = h==10'd704;
  wire circle_start = (h==10'd640 || circle_inner_start);
  wire [5:0] circle_radius = (h >= 10'd704) ? 6'd53 : 6'd63; // Inner vs. outer radius.

  reg [5:0] circle_outer_edge;

  wire [9:0] cvo = v-112;

  wire [19:0] circle_bits = 20'b01111111111111111100;
  //////////////////////////////////^

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

  wire [9:0] cho = h^64;
  wire [5:0] circle_scan = cho[6] ? cho[5:0] : ~cho[5:0];
  wire in_outer_circle = (circle_scan > circle_outer_edge);
  wire in_inner_circle = (circle_scan > circle_edge);
  wire logo_upper_half = (cvo[9:6] == 4'd1);
  wire logo_lower_half = (cvo[9:6] == 4'd2);
  wire in_circle = circle_valid && in_outer_circle && !in_inner_circle && circle_bits[h[9:5]] && !(h[9:5]==15 && logo_lower_half);
  wire in_logo = (logo_upper_half || logo_lower_half) && (h>32) && (h<640-32);
  wire in_tt_logo = (h[9:8]==2'b01);
  assign logo_hit = in_logo && (
    in_circle || // Circle frame.
    h<42 || // "D" left bar.
    (h>=598 && logo_upper_half && cvo>74) || // Final E top-right bar.
    ((cvo<74 || cvo>182) && (h[9:5]==1)) || // "D" top and bottom bars.
    (cvo>123 && cvo<133 && cho[9:7]>=3) || // "E" middle bar.
    (
        // "TT" inner:
        //NOTE: Instead of constraining the rectangles' left/bottom, just clip with in_outer_circle.
        //NOTE: We could get away with fudging 1 pixel to prefer even-numbered comparisons, if it saves 1 bit here and there.
        (
          (cvo>(64+27) && cvo<=(64+44)           && h<332 && in_tt_logo ) ||  // Upper bar; clipped by circle.
          (cvo>(64+58) && cvo< (64+76)  && h>300 && h<361               ) ||  // Lower bar.
          (cvo>(64+27) && cvo<=(64+87)  && h>293 && h<313               ) ||  // Upper post.
          (cvo>(64+58)                  && h>323 && h<343 && in_tt_logo )     // Lower post; clipped by circle.
        ) && in_outer_circle
    )
  ) && ~(
      // Gaps in TT ring:
      ( in_tt_logo && h<276 && cvo>(64+44) && cvo<(64+52) ) ||
      (      h>342 && h<349 && cvo>(64+100))
  );

endmodule
