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

  wire [5:0] rgb = counter[9:4]^6'b11_10_00; // For now, background is just a colour that gets tinted down ('gems' should get optimised out).
  wire [5:0] rgb_gems;

  gems #(.DOTBITS(6)) gems1(
    .h(h),
    .v(v+counter),
    .counter(counter),
    .rgb(rgb_gems)
  );

  wire logo_hit;

  dottee_logo logo(
    .clk(clk),
    .reset(reset),
    .h(h),
    .v(v),
    .logo_hit(logo_hit)
  );

  wire in_logo_stripe = (v[8:3] >= 6'b010001) && (v[8:3] <= 6'b101010); // (v>136) && (v<344);

  assign {R,G,B} =
    (!video_active)   ? 6'b00_00_00 :
    (logo_hit)        ? 6'b11_11_11 :
    (in_logo_stripe)  ? ((rgb>>1)&6'b01_01_01) :
                      rgb;

  always @(posedge vsync, negedge rst_n) begin
    if (reset) begin
      counter <= 0;
    end else begin
      counter <= counter + 1;
    end
  end

endmodule
