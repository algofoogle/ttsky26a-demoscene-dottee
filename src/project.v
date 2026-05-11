/*
 * Copyright (c) 2026 Anton Maurovic
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// // `define DEBUG_GATES   // Gate certain functions using ui_in.
// `define DEBUG_BAR     // Show the progress bar.
// `define DEBUG_GEM_MODE_SHOW
// `define DEBUG_GEM_MODE_UI
// `define DEBUG_DAC
// // For debugging, optionally constrain demo frame_counter to a given timeframe:
// // Short initial delay, loop early:
// `define DEBUG_TSTART  ( 2*60)
// `define DEBUG_TSTOP   (20*60) 
// `define DEBUG_SLOW    5

// `define SPIN_LOGO
// `define SIMPLE_LOGO_REVEAL


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
  localparam AUDIO_BITS = 6;
  localparam AUDIO_SUB = 7;

  wire dac_out; //NOTE: This is (probably) already registered, within the 'audio' module.
  wire speaker = dac_out;

  wire line_end;

  audio #(.B(AUDIO_BITS), .SUB(AUDIO_SUB)) synth (
    .clk(clk),
    .rst_n(rst_n),
    .frame_counter(frame_counter),
    .sample_clk(line_end),
    .dac_out(dac_out)
  );

  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire video_active;
  wire [9:0] h;
  wire [9:0] v;

`ifdef DEBUG_GATES
  wire en_r = ui_in[0];
  wire en_g = ui_in[1];
  wire en_b = ui_in[2];
  wire en_counter = ui_in[3];
`else
  wire en_r = 1;
  wire en_g = 1;
  wire en_b = 1;
  wire en_counter = 1;
`endif


  wire [3:0] gem_mode;
`ifdef DEBUG_GEM_MODE_UI
  assign gem_mode = ui_in[7:4]; // User inputs select gem mode.
`else
  assign gem_mode = frame_counter[11:8]; // Show each gem mode for ~4 seconds.
`endif

  // wire [2:0] gem_bmode = ui_in[6:4];

  // TinyVGA PMOD with registered outputs
  // NOTE: Only colours are registered, since hsync/vsync jitter is unlikely.
  reg [5:0] RGB_reg;
  always @(posedge clk) RGB_reg <= {B[0], G[0], R[0], B[1], G[1], R[1]};
  assign uo_out = {hsync, RGB_reg[5:3], vsync, RGB_reg[2:0]};

  // TT Audio PMOD
  assign uio_out[7] = speaker;
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
    .rst_n(rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .visible(video_active),
    .hpos(h),
    .vpos(v),
    .hmax(line_end)
  );

  wire [5:0] rgb_gate = { {2{en_r}}, {2{en_g}}, {2{en_b}} };

  wire fuzz = h[0]^v[0];
  wire tfuzz = fuzz^counter[0];

  reg [5:0] rgb_slide;
  wire [1:0] simples = rgb_gems[5:4];
  always @(*) begin
    case (counter[4] ? counter[3:0] : ~counter[3:0])
    4'd0: rgb_slide = {5'd0,simples[1]&tfuzz};
    4'd1: rgb_slide = {5'd0,simples[1]&tfuzz};
    4'd2: rgb_slide = {5'd0,simples[1]&tfuzz};
    4'd3: rgb_slide = {5'd0,simples[1]&tfuzz};
    4'd4: rgb_slide = {5'd0,simples[1]&tfuzz};
    4'd5: rgb_slide = {5'd0,simples[1]&tfuzz};
    4'd6: rgb_slide = {5'd0,simples[1]&tfuzz};
    4'd7: rgb_slide = {5'd0,simples[1]};
    4'd8: rgb_slide = {5'd0,simples[1]};
    4'd9: rgb_slide = {5'd0,simples[1]};
    4'd10: rgb_slide = {5'd0,simples[1]};
    4'd11: rgb_slide = {5'd0,simples[1]};
    4'd12: rgb_slide = {4'd0,simples};
    4'd13: rgb_slide = {4'd0,simples};
    4'd14: rgb_slide = {4'd0,simples};
    4'd15: rgb_slide = {2'd0,simples[1:0],simples|2'b1};
    endcase
  end

  wire [9:0] hvdelta = (h-(counter<<5)^10'b1000000000)+(v>>1);
  wire start_diag_wipe = frame_counter >= 12'b0011111_10000;
  wire within_whiteout = frame_counter >= 12'b0100000_00000 && (frame_counter < 12'b0100000_10000);
  wire diag_wipe = (hvdelta[9:7] == 0) && (start_diag_wipe) && (frame_counter < 12'b0100000_01100);
  wire full_color = (frame_counter >= 12'b0100000_10000);

  reg [5:0] whiteout;
  always @(*) begin
    if (within_whiteout) begin
      case (counter[3:0])
      4'd0: whiteout = 6'b01_00_00;
      4'd1: whiteout = 6'b01_01_00;
      4'd2: whiteout = 6'b10_01_00;
      4'd3: whiteout = 6'b10_10_00;
      4'd4: whiteout = 6'b11_10_00;
      4'd5: whiteout = 6'b11_11_00;
      4'd6: whiteout = 6'b11_11_01;
      4'd7: whiteout = 6'b11_11_11;
      4'd8: whiteout = 6'b11_11_11;
      4'd9: whiteout = 6'b11_11_11;
      default: whiteout = 6'b11_11_11;
      endcase
    end else begin
      whiteout = 0;
    end
  end

  wire [5:0] rgb = rgb_gate & ((
    (diag_wipe | full_color) ? rgb_gems : rgb_slide
  ));

  wire [5:0] rgb_gems;

  wire logo_gone   = frame_counter>=12'd1024;
  wire logo_en     = frame_counter>=12'd512 && !logo_gone;    // Logo visible from 00:06.4 to 00:17.1
  wire shatter_in  = frame_counter[9:5]==5'b10000; //5'b01110;
  wire shatter_out = frame_counter[9:5]==5'b11111;

  wire logo_revealed = frame_counter[11:5]>=7'b0001101;

  wire [9:0] logo_shatter =
    shatter_in  ? {5'd0,~frame_counter[4:0]} : 0;
    // shatter_out ? {5'd0, frame_counter[4:0]} : 0;

`ifdef SPIN_LOGO
  // Logic for handling logo spin (inc. colour):
  reg [2:0] logo_spin; // False reg.
  reg logo_reverse; // False reg.
  always @(*) begin
    case (frame_counter[5:2])
      4'd0:  begin logo_reverse=0; logo_spin=0; end
      4'd1:  begin logo_reverse=0; logo_spin=1; end
      4'd2:  begin logo_reverse=0; logo_spin=2; end
      4'd3:  begin logo_reverse=0; logo_spin=3; end
      4'd4:  begin logo_reverse=0; logo_spin=4; end
      4'd5:  begin logo_reverse=1; logo_spin=3; end
      4'd6:  begin logo_reverse=1; logo_spin=2; end
      4'd7:  begin logo_reverse=1; logo_spin=1; end
      4'd8:  begin logo_reverse=1; logo_spin=0; end
      4'd9:  begin logo_reverse=1; logo_spin=1; end
      4'd10: begin logo_reverse=1; logo_spin=2; end
      4'd11: begin logo_reverse=1; logo_spin=3; end
      4'd12: begin logo_reverse=0; logo_spin=4; end
      4'd13: begin logo_reverse=0; logo_spin=3; end
      4'd14: begin logo_reverse=0; logo_spin=2; end
      4'd15: begin logo_reverse=0; logo_spin=1; end
    endcase
  end

  // wire [11:0] spin_delayed = frame_counter-11'b00011010000;
  wire [9:0] logo_hspin =
    (logo_reverse) ?  (((640-h)^logo_shatter) << logo_spin) :
                      ((h^logo_shatter) << logo_spin);
  wire in_tt_logo = h>=(320-64) && h<(320+64);

  wire [2:0] lst = 5-logo_spin;
  wire [5:0] logo_color =
    (logo_spin==0 || !in_tt_logo) ? ~logo_shatter[5:0] :
    logo_reverse  ? (tfuzz ? 6'b10_11_11 : 6'b01_10_10) :
    tfuzz         ? 6'b01_01_01 :
                    { 2'b00,
                      lst[2], &lst[1:0],
                      |lst[2:1], (|lst[2:1])^lst[0]
                    };

`else
  // Regular non-spinning logo colour:
  wire [5:0] logo_color = ~logo_shatter[5:0];

`endif//SPIN_LOGO

  // wire [9:0] logo_bounce = (counter[9:5]<=5'b10000) ? 0 : (1<<( counter[3] ? ~counter[2:0] : counter[2:0] ));
  wire logo_hit_raw;

`ifdef SIMPLE_LOGO_REVEAL
  wire [9:0] hlogo = h;
`else
  wire [9:0] hlogo = h^logo_shatter;
`endif//SIMPLE_LOGO_REVEAL

  circle_edge ce_shared(
    // Inputs:
    .clk(clk),
    .rst_n(rst_n),
    .radius(ce_radius),
    .vertical_line(ce_vline), 
    .start(ce_start),
    // Outputs:
    .done(ce_done),
    .valid(ce_valid),
    .edge_point(ce_edge)
  );

  wire [5:0] logo_ce_radius;
  wire [5:0] logo_ce_vline;
  wire       logo_ce_start;

  // For now, the inputs to the "shared" circle_edge (ce_shared) module are just mastered by dottee_logo:
  wire [5:0] ce_radius = logo_ce_radius;
  wire [5:0] ce_vline = logo_ce_vline;
  wire       ce_start = logo_ce_start;
  wire       ce_done;
  wire       ce_valid;
  wire [5:0] ce_edge; // Computed edge horizontal distance.

  dottee_logo logo(
    .clk(clk),
    .rst_n(rst_n),
    .counter(counter),
    .realh(hlogo), // Drives internal state machines.
    .v((v^logo_shatter)),// - logo_bounce),
`ifdef SPIN_LOGO
    .h(in_tt_logo ? (logo_hspin+320-(320 << logo_spin)) : hlogo),
    .tt_only(in_tt_logo),
`else
    .h(hlogo),
    .tt_only(0),
`endif//SPIN_LOGO
    .logo_hit(logo_hit_raw),
    // Interface to the shared circle_edge (ce_shared) module:
    .ceo_radius(logo_ce_radius),
    .ceo_vline(logo_ce_vline),
    .ceo_start(logo_ce_start),
    .cei_done(ce_done),
    .cei_valid(ce_valid),
    .cei_edge(ce_edge)
  );

`ifdef SPIN_LOGO
  wire logo_hit = logo_hit_raw && (~in_tt_logo || (h>=(320-(64>>logo_spin)) && h<(320+(64>>logo_spin))));
`else
  wire logo_hit = logo_hit_raw;
`endif

  wire gem_hit;

  wire [9:0] vgems = v+counter+(1<<(DOTBITS-1));

  wire hstagger = vgems[DOTBITS]; // Half offset alternate rows of gems?

  wire [DOTBITS-1:0] max_radius =
    (hlut<<2) + frame_counter[5:0]; //({6{frame_counter[6]}} ^ frame_counter[5:0]); //(1<<(DOTBITS-1));

  wire [DOTBITS-3:0] hlut;
  wire [DOTBITS-3:0] vlut;

  // wire altgem = (gem_mode == 4) && (max_radius >= 32);

  // wire [9:0] hslide = (&frame_counter[11:10]) ? (frame_counter[9:2] ^ {6{vlut[0]}}) : 0;

  gems #(.DOTBITS(DOTBITS)) gems1(
    .h( (hstagger ? h+(1<<(DOTBITS-1)) : h)),// + hslide),
    .v(v+counter),
    .counter(logo_revealed ? ~(counter+256) : 0), // Start animating dots after the logo has been fully-revealed.
    // .fmode(15),
    .fmode(gem_mode),//   (gem_mode != 4) ? gem_mode : ((max_radius>=32) ? 5 : 4)),
    // .fmode(altgem ? 5 : gem_mode),//   (gem_mode != 4) ? gem_mode : ((max_radius>=32) ? 5 : 4)),
    // .bmode(gem_bmode),
    // .bmode(altgem ? 0 : 3), // 0 is black. 1 is original. 7 is blue/magenta.
    .bmode(3), // 0 is black. 1 is original. 7 is blue/magenta.
    .inr(max_radius), //NOTE: Intentionally or not, radius behaves as the absolute of a signed value??
    .hit(gem_hit),
    .hlut(hlut),
    .vlut(vlut),
    .rgb(rgb_gems)
  );

`ifdef DEBUG_BAR
  wire debug_bar_en = v[9:3] == (480-8)>>3;
  wire debug_limit = (h[9]);
  wire debug_progress = (frame_counter[11:3]>=h);
`endif//DEBUG

`ifdef DEBUG_GEM_MODE_SHOW
  // gem_mode displayed as 4 binary bits (MSB first) in bottom-right screen corner:
  wire debug_gem_mode_en = (v[9:3] == (480-8)>>3) && (h>=(640-32));
  wire debug_gem_mode_p = gem_mode[~h[4:3]]; // "Pixels" are 8-wide and there's 4 of them.
`endif//DEBUG_GEM_MODE_UI

  wire [5:0] rgb_unblanked = 
`ifdef DEBUG_DAC
    (h>=10'd544) ? {2'b00,{2{dac_out}}, 2'b00} :
`endif
`ifdef DEBUG_GEM_MODE_SHOW
    (debug_gem_mode_en) ? {6{debug_gem_mode_p}} :
`endif//DEBUG_GEM_MODE_SHOW
`ifdef DEBUG_BAR
    (debug_bar_en && (debug_limit || debug_progress)) ? {6{fuzz}} :
`endif//DEBUG_BAR
(
    (logo_hit && logo_en) ? logo_color :
                          rgb) | whiteout;

  assign {R,G,B} = (!video_active) ? 6'b00_00_00 : rgb_unblanked;


`ifdef DEBUG_SLOW
  reg [3:0] debug_slow;
`endif

  always @(posedge vsync, negedge rst_n) begin
    if (~rst_n) begin
      `ifdef DEBUG_TSTART
      frame_counter <= `DEBUG_TSTART;
      `else      
      frame_counter <= 0;
      `endif

      `ifdef DEBUG_SLOW
      debug_slow <= 0;
    end else if (debug_slow != `DEBUG_SLOW) begin
      debug_slow <= debug_slow + 1;
    end else begin
      debug_slow <= 0;
      if (0) begin
      `endif

      `ifdef DEBUG_TSTOP
      end else if (frame_counter==`DEBUG_TSTOP-1) begin
        `ifdef DEBUG_TSTART
        frame_counter <= `DEBUG_TSTART;
        `else
        frame_counter <= 0;
        `endif
      `endif
    end else begin
      frame_counter <= frame_counter + 1;
    end

`ifdef DEBUG_SLOW
  end
`endif

  end

endmodule
