/*
 * Copyright (c) 2026 Anton Maurovic
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// `define DEBUG

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

`ifdef DEBUG
  wire en_r = ui_in[0];
  wire en_g = ui_in[1];
  wire en_b = ui_in[2];
  wire en_counter = ui_in[7];
`else
  wire en_r = 1;
  wire en_g = 1;
  wire en_b = 1;
  wire en_counter = 1;
`endif

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

  reg [11:0] frame_counter; // 4096 frames ~= 68 seconds.
  wire [9:0] counter = en_counter ? frame_counter[9:0] : 0;

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(reset),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(h),
    .vpos(v)
  );

  wire [5:0] rgb_gate = { {2{en_r}}, {2{en_g}}, {2{en_b}} };

  reg [5:0] rgb_slide;
  wire [1:0] simples = rgb_gems[5:4];
  always @(*) begin
    case (counter[5] ? counter[4:3] : ~counter[4:3])
    2'd0: rgb_slide = 0;//{2'd0,rgb_gems[3]&rgb_gems[2],simples[1],simples};
    2'd1: rgb_slide = {5'd0,simples[1]};
    2'd2: rgb_slide = {4'd0,simples};
    2'd3: rgb_slide = {2'd0,simples[1:0],simples|2'b1};
    endcase
  end

  wire [5:0] rgb = rgb_slide & rgb_gate; //counter[9:4]^6'b11_10_00; // For now, background is just a colour that gets tinted down ('gems' should get optimised out).
  wire [5:0] rgb_gems;

  gems #(.DOTBITS(6)) gems1(
    .h(h),
    .v(v+counter),
    .counter(0),//counter),
    .rgb(rgb_gems)
  );

  wire logo_hit;

  wire logo_en     = frame_counter>=12'd384 && frame_counter<12'd1024;    // Logo visible from 00:06.4 to 00:17.1
  wire shatter_in  = frame_counter[9:5]==5'b01100;
  wire shatter_out = frame_counter[9:5]==5'b11111;

  wire [9:0] logo_shatter =
    shatter_in  ? {5'd0,~frame_counter[4:0]} :
    shatter_out ? {5'd0, frame_counter[4:0]} : 0;

  wire [5:0] logo_color = ~logo_shatter[5:0];

  // wire [9:0] logo_bounce = (counter[9:5]<=5'b10000) ? 0 : (1<<( counter[3] ? ~counter[2:0] : counter[2:0] ));

  dottee_logo logo(
    .clk(clk),
    .reset(reset),
    .counter(counter),
    .h(h^logo_shatter),
    .v((v^logo_shatter)),// - logo_bounce),
    .logo_hit(logo_hit)
  );

  wire in_logo_stripe = (v[8:3] >= 6'b010001) && (v[8:3] <= 6'b101010); // (v>136) && (v<344);

`ifdef DEBUG
  wire debug_bar_en = v[9:3] == (480-8)>>3;
  wire debug_limit = (h[9]);
  wire debug_progress = (frame_counter[11:3]>=h);
`endif//DEBUG

  wire in_logo_shade =
    ((v[8:5] == 4 || v[8:5] == 10) && (h[0]&v[0])) ||
    ((v[8:5] >= 5 && v[8:5] <= 9) && (h[0]^v[0]^counter[0]));
  
  assign {R,G,B} =
    (!video_active)       ? 6'b00_00_00 :
`ifdef DEBUG
    (debug_bar_en && (debug_limit || debug_progress)) ? {6{(h[0]^v[0])}} :
`endif//DEBUG
    (logo_hit && logo_en) ? logo_color :
    (in_logo_shade)      ? ((rgb>>1)&6'b01_01_01) :
                          rgb;

  always @(posedge vsync, negedge rst_n) begin
    if (~rst_n) begin
      frame_counter <= 0;
    end else begin
      frame_counter <= frame_counter + 1;
    end
  end

endmodule
