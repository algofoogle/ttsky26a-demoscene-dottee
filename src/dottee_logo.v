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

  wire [19:0] circle_bits = 20'b01110111111111111100;

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
  wire in_circle = circle_valid && in_outer_circle && !in_inner_circle && circle_bits[h[9:5]];
  wire in_logo = (cvo[9:6] == 1 || cvo[9:6] == 2) && (h>32) && (h<640-32);
  assign logo_hit = in_logo && (
    in_circle ||
    h<42 ||
    ((cvo<74 || cvo>182) && (h[9:5]==1)) ||
    (cvo>123 && cvo<133 && cho[9:7]>=3) ||
    (
        // "TT" inner:
        //NOTE: Instead of constraining the rectangles' left/bottom, just clip with in_outer_circle.
        //NOTE: We could get away with fudging 1 pixel to prefer even-numbered comparisons, if it saves 1 bit here and there.
        (
          (cvo>(64+27) && cvo<=(64+44) && h>268 && h<332) ||  // Upper bar.
          (cvo>(64+58) && cvo<(64+76) && h>300 && h<361) ||   // Lower bar.
          (cvo>(64+27) && cvo<=(64+87) && h>293 && h<313) ||  // Upper post.
          (cvo>(64+58) && cvo<=(64+123) && h>323 && h<343)    // Lower post.
        ) 
    )
  ) && ~(
      // Gaps in TT ring:
      ( h>256 && h<276 && cvo>(64+44) && cvo<(64+52) ) ||
      ( h>342 && h<349 && cvo>(64+100))
  );

endmodule
