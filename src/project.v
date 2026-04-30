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
  wire [9:0] v;

  wire reset = ~rst_n;

  // TinyVGA PMOD with registered outputs
  // NOTE: Only colours are registered, since hsync/vsync jitter is unlikely.
  reg [5:0] RGB_reg;
  always @(posedge clk) RGB_reg <= {B[0], G[0], R[0], B[1], G[1], R[1]};
  assign uo_out = {hsync, RGB_reg[5:3], vsync, RGB_reg[2:0]};

  // TT Audio PMOD
  assign uio_out[7] = 0;
  assign uio_oe[7] = 1;

  // Unused outputs assigned to 0.
  assign uio_out[6:0] = 0;
  assign uio_oe[6:0]  = 0;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in, uio_in};

  reg [9:0] counter;

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(reset),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(h),
    .vpos(v)
  );

  wire [5:0] rgb = rgb_gems; //counter[9:4]^6'b11_10_00; // For now, background is just a colour that gets tinted down ('gems' should get optimised out).
  wire [5:0] rgb_gems;

  wire [9:0] rzh;
  wire [9:0] rzv;

  gems #(.DOTBITS(6)) gems1(
    .h(rzh),
    .v(rzv),//+counter),
    .counter(counter),
    .rgb(rgb_gems)
  );

  wire logo_hit;

  dottee_logo logo(
    .clk(clk),
    .reset(reset),
    .counter(counter),
    .h(h),
    .v(v),
    .logo_hit(logo_hit)
  );

  checkerboard checks(
    // .rgb(rgb_gems),
    .h(rzh),
    .v(rzv)
  );

  roto rotozoom_displace(
    .clk(clk),
    .rst_n(rst_n),
    .counter(counter),
    .pix_x(h),
    .pix_y(v),
    .rzx(rzh),
    .rzy(rzv)
  );

  wire in_logo_stripe = (v[8:3] >= 6'b010001) && (v[8:3] <= 6'b101010); // (v>136) && (v<344);

  wire [9:0] crossx = 138;
  wire [9:0] crossy = 294;

  assign {R,G,B} =
    (!video_active)   ? 6'b00_00_00 :
    // (h==crossx)       ? 6'b00_10_00 :     (v==crossy)       ? 6'b00_10_00 :
    (logo_hit && 0)        ? 6'b11_11_11 :
    // (in_logo_stripe)  ? ((rgb>>1)&6'b01_01_01) :
                      rgb;

  always @(posedge vsync, negedge rst_n) begin
    if (~rst_n) begin
      counter <= 0;
    end else begin
      counter <= counter + 1;
    end
  end

endmodule

module checkerboard(
  input [9:0] h,
  input [9:0] v,
  output [5:0] rgb
);
  assign rgb =
    (h[9:5]==2 && v[9:5]==2)  ? 6'b11_00_00
                              : {6{h[6]^v[6]}};
endmodule


module roto #(
  parameter B=6 // 4 is interesting and visually confusing: Seems to have 2 pivots. 
) (
  input clk,
  input rst_n,
  input [9:0] counter,
  input [9:0] pix_x,
  input [9:0] pix_y,
  output [9:0] rzx,
  output [9:0] rzy
);

  localparam MSB=B-1;
  localparam RMSB=10+B-3; //NOTE: When B=6, can kinda get away with -4 instead of -3.
  localparam ROFF=(1<<(B+1));

  // False reg:
  reg [9:0] c; //counter[9:4];

  always @(*) begin
    c = 31;
    c = 32;
    c = 8; // 45deg.
    // c = counter[9:0]^10'b0000100000;
    c = (counter[9:0]^(1<<MSB));
  end

  //wire [7:0] XVEC = counter[7:0] ^ {8{counter[8]}}; //(counter[8] ? counter[7:0] : ~counter[7:0]) + 8'b10000000;

  //localparam XVEC = 8'b10110101; // (1/sqrt(2))<<8

  wire signed [MSB:0] xvec = 6'b001000; //5'b01001; //8'b10010110; // sin(36) = ~0.5878 = 0.10010110
  wire signed [MSB:0] yvec = 6'b000000 + ({MSB{c[MSB]}} ^ c[B-2:0]); //5'b01100; //8'b11001111; // cos(36) = ~0.8090 = 0.11001111

  reg signed [RMSB:0] ox, oy, nx, ny;

  always @(posedge clk) begin
    if (~rst_n || (pix_x==799 && pix_y==524)) begin
      ox <= 0;
      oy <= 0;
      nx <= 0;
      ny <= 0;
    end else if (pix_x==799) begin
      // Go to next line.
      ox <= ox - yvec;
      oy <= oy + xvec;
      nx <= ox - yvec;
      ny <= oy + xvec;
    end else begin
      nx <= nx + xvec;
      ny <= ny + yvec;
    end
  end
  
  //wire [9:0] moving_x = pix_x + counter;

  assign rzx = nx[RMSB:B-2]-(c[MSB] ? (c<<(B-2))+(1<<(B-2))+ROFF : ROFF-(c<<(B-2)));
  assign rzy = ny[RMSB:B-2]+(c[MSB] ? (c<<(B-2))+(1<<(B-2))      : ~(c<<(B-2)));

endmodule

