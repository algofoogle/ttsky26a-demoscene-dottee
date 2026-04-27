/*
 * Copyright (c) 2026 Anton Maurovic
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_algofoogle_dottee(
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
);

  localparam DOTBITS = 6; //NOTE: Increasing to 6 gives quadrant colours, like gems.

  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire video_active;
  wire [9:0] h;
  // + (v[6]<<5) // Worm
  // + (v>>5) // Minor shift makes it more interesting.
  wire [9:0] v;

  // TinyVGA PMOD with registered outputs
  reg [9:0] uo_out_reg;
  always @(posedge clk) begin
    if (~rst_n)
      uo_out_reg <= 0;
    else
      uo_out_reg <= {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  end
  assign uo_out = uo_out_reg;

  // TT Audio PMOD
  assign uio_out[7] = 0;//(&counter[0:0]) ? hit : (delta[7] ^ r[4]); // Weird motor sound: d[4] ^ r[1]; Also try d[9]
  assign uio_oe[7] = 1;

  // Unused outputs assigned to 0.
  assign uio_out[6:0] = 0;
  assign uio_oe[6:0]  = 0;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in, uio_in};

  reg [9:0] counter;

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(h),
    .vpos(v)
  );

  wire [5:0] rgb;
  wire [5:0] rgb1;
  wire [5:0] rgb2;

  //assign rgb = (0) ? rgb1 : rgb2;//rgb2<<(rgb1>>2);
  // Also pretty (but currently for static BG, no motion):
  //assign rgb = ((((h-16)&9'b100000)^((v-16)&9'b100000))&&(h[6]^v[6])) ? rgb1 : rgb2;//rgb2<<(rgb1>>2); // Can make fish scales with dense half-circles.

  assign rgb = rgb1;

  reg [19:0] hlut;

  background_generator #(.DOTBITS(6)) bgen(
    .h(h),//-counter),
    .v(v+counter),
    .counter(counter),
    .rgb(rgb1)
  );

  background_generator #(.DOTBITS(6)) bgen2(
    .h(hlut[11:2]+32-counter),
    .v(v+32),
    .counter(counter),
    .rgb(rgb2)
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
    .reset(~rst_n),
    .radius(circle_radius),
    .vertical_line(cvo[6] ? cvo[5:0] : ~cvo[5:0]),
    .start(circle_start),
    .done(circle_done),
    .valid(circle_valid),
    .edge_point(circle_edge)
  );

  always @(posedge clk) begin
    if (~rst_n)
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
  wire logo_hit = in_logo && (
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
  wire in_logo_stripe = (v>136) && (v<344);

  assign {R,G,B} =
    (!video_active) ? 6'b00_00_00 :
    (logo_hit)      ? 6'b11_11_11 :
    (in_logo_stripe & (h[0]^v[0])) ? 0 :
                      rgb;

  // wire [9:0] dist2 = $signed(h[5:0]) * $signed(v[5:0]);
  // wire [9:0] comp = $signed(counter*counter)+v+h*v; //$signed(h[9:3]*h[9:3]+counter);
  // wire hit2 = dist2 < comp;
  // wire [5:0] dithery = (counter+{h[3:2],h[5:4],h[9:6]}) & {6{hit2}} & {6{video_active}};

  always @(posedge clk) begin
    if (h == 0 || ~rst_n) begin
      hlut <= 0;
    end else begin
      hlut <= hlut + 4;
    end
  end

  always @(posedge vsync, negedge rst_n) begin
    if (~rst_n) begin
      counter <= 0;
    end else begin
      counter <= counter + 1;
    end
  end


endmodule


module background_generator #(
  parameter DOTBITS=6
) (
  input [9:0] h,
  input [9:0] v,
  input [9:0] counter,
  output [5:0] rgb
);

  wire signed [9:0] dx = $signed(h[DOTBITS-1:0]);
  wire signed [9:0] dy = $signed(v[DOTBITS-1:0]);

  wire [19:0] d = dx*dx + dy*dy;

  // wire [9:0] r = (counter[DOTBITS-2:0] ^ {(DOTBITS-1){counter[DOTBITS-1]}}) * ({2{hc[7]}} ^ hc[6:5]);

  wire [9:0] r = (counter[DOTBITS-2:0] ^ {(DOTBITS-1){counter[DOTBITS-1]}}) + 1 + ({3{hc[8]}} ^ hc[7:5]);

  wire [9:0] hc = h+(1<<(DOTBITS-1));
  wire [9:0] vc = v+(1<<(DOTBITS-1));
  wire [9:0] hvc = {hc[9:5]+vc[9:5],1'b0} + (counter>>0);

  wire hit = d < r*r; // Also try: h[0]^v[0] ? 0 : d < r*r; and simply: 1;
  wire [9:0] delta = d + r*r; // Subtracting is nice, but so is adding and other logical ops.
  wire [5:0] color = hvc;

  wire [5:0] white = 6'b11_11_11;

  wire sheen = (hc[DOTBITS-1:2]==4'b101 && vc[DOTBITS-1:2]==4'b101);// ||
               //(hc[DOTBITS-1:4]==delta[2:1] && vc[DOTBITS-1:4]==delta[2:1] && (hc[0] ^ vc[0]));

  wire [5:0] altcolor = delta[9:4]; // [9:8] also gives nice blues, and +r is interesting. // &d[9:4] nice anti-tones. // &hvc[9:4] // &counter[9:4] or r or dist2

  assign rgb = 
    sheen ? white :
    hit ? (delta[9:6]+color) : altcolor;  //(dithery & 6'b01_01_01);

endmodule
