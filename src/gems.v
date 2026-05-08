// `define CLASSIC_SQ // If defined, use "classic" squaring with real x*x. Else, use a LUT of squares.
`define ROUGH_LUT_6B // Use a LUT of rough approximations (expected to optimise better) for fixed 6-bit-wide squares.
// `define TRUE_SQ // Should LUT square use true negatives?

`ifndef CLASSIC_SQ
`ifdef ROUGH_LUT_6B

  // This is a rough-approximation 6-bit-only implementation that allows +/-8 error.
  module sqalut #(
    parameter B=6 // NOT USED. Dummy, for swapping this for the parametric version of 'sqalut'.
  ) (
    input  [5:0]  a,
    output reg [11:0] y
  );

    wire [4:0] idx = {5{a[5]}} ^ a[4:0];

    always @(*) begin
      case (idx)
        5'd0:  y = 12'd0;    // exact 0
        5'd1:  y = 12'd0;    // exact 1
        5'd2:  y = 12'd0;    // exact 4
        5'd3:  y = 12'd16;   // exact 9, error +7
        5'd4:  y = 12'd16;
        5'd5:  y = 12'd32;   // exact 25, error +7
        5'd6:  y = 12'd32;   // exact 36, error -4
        5'd7:  y = 12'd48;   // exact 49, error -1
        5'd8:  y = 12'd64;
        5'd9:  y = 12'd80;   // exact 81, error -1
        5'd10: y = 12'd96;   // exact 100, error -4
        5'd11: y = 12'd128;  // exact 121, error +7
        5'd12: y = 12'd144;
        5'd13: y = 12'd176;  // exact 169, error +7
        5'd14: y = 12'd192;  // exact 196, error -4
        5'd15: y = 12'd224;  // exact 225, error -1
        5'd16: y = 12'd256;
        5'd17: y = 12'd288;  // exact 289, error -1
        5'd18: y = 12'd320;  // exact 324, error -4
        5'd19: y = 12'd368;  // exact 361, error +7
        5'd20: y = 12'd400;
        5'd21: y = 12'd448;  // exact 441, error +7
        5'd22: y = 12'd480;  // exact 484, error -4
        5'd23: y = 12'd528;  // exact 529, error -1
        5'd24: y = 12'd576;
        5'd25: y = 12'd624;  // exact 625, error -1
        5'd26: y = 12'd672;  // exact 676, error -4
        5'd27: y = 12'd736;  // exact 729, error +7
        5'd28: y = 12'd784;
        5'd29: y = 12'd848;  // exact 841, error +7
        5'd30: y = 12'd896;  // exact 900, error -4
        5'd31: y = 12'd960;  // exact 961, error -1
      endcase
    end

  endmodule

`else // !ROUGH_LUT_6B...

  // LUT-based Approximate Square:
  module sqalut #(
    parameter B = 5
  ) (
    input [B-1:0] a,
    output reg [(B*2)-1:0] y
  );
    localparam MB = B-1; // Max bit index (0-based). Nom: 4
    localparam MLB = MB-1; // Max bit index of LUT index. Nom: 3
    localparam N = 1<<MB; // Number of entries. Nom: 1<<4 = 16
    wire neg = a[MB]; // Is the input negative?
  `ifdef TRUE_SQ
    wire [MLB:0] lut_index = (a[MLB:0] ^ {MB{neg}}) + {{(MLB-1){1'b0}}, neg}; // True absolute.
  `else
    wire [MLB:0] lut_index = (a[MLB:0] ^ {MB{neg}}); // Approximate absolute (off-by-one for negative values).
  `endif

    integer i;

    always @(*) begin
  `ifdef TRUE_SQ
      if (a == (1<<MB)) begin // Nom: 5'b10000
        y = (1<<(MB*2)); // Absolute max. negative, squared. Nom: 16*16=256.
      end else begin
  `endif
        y = 0; // Guarantee no inferred latches.
        for (i=0; i<N; i=i+1) begin
          if (lut_index == i[MLB:0])
            y = i*i;
        end
  `ifdef TRUE_SQ
      end
  `endif
    end
  endmodule

`endif // !ROUGH_LUT_6B
`endif // CLASSIC_SQ


module gems #(
  parameter DOTBITS=6
) (
  input [9:0] h,
  input [9:0] v,
  input [9:0] counter,
  input [3:0] fmode, // Front effect mode.
  input [2:0] bmode, // Background effect mode.
  input [DOTBITS-1:0] inr,
  // output [DOTBITS-1:0] hlut,
  // output [DOTBITS-1:0] vlut,
  output [5:0] rgb,
  output hit
);

  wire [9:0] hc = h+(1<<(DOTBITS-1));
  wire [9:0] vc = v+(1<<(DOTBITS-1));
  // wire [9:0] r = (counter[DOTBITS-2:0] ^ {(DOTBITS-1){counter[DOTBITS-1]}}) * ({2{hc[7]}} ^ hc[6:5]);
  wire [9:0] r =
    fmode==15 ? inr :
                (counter[DOTBITS-2:0] ^ {(DOTBITS-1){counter[DOTBITS-1]}}) + 1 + ({3{hc[8]}} ^ hc[7:5]);

  wire signed [9:0] dx = $signed(h[DOTBITS-1:0]);
  wire signed [9:0] dy = $signed(v[DOTBITS-1:0]);

`ifdef CLASSIC_SQ
  wire signed [19:0] dx2 = dx*dx;
  wire signed [19:0] dy2 = dy*dy;
  wire signed [19:0] r2 = r*r;
`else
  wire [(DOTBITS*2)-1:0] dx2;
  wire [(DOTBITS*2)-1:0] dy2;
  wire [(DOTBITS*2)-1:0] r2;

  sqalut #(.B(DOTBITS)) sqx(.a(dx[DOTBITS-1:0]), .y(dx2));
  sqalut #(.B(DOTBITS)) sqy(.a(dy[DOTBITS-1:0]), .y(dy2));
  sqalut #(.B(DOTBITS)) sqr(.a( r[DOTBITS-1:0]), .y( r2));
`endif

  wire [19:0] d = dx2 + dy2;

  wire [9:0] hvc = {hc[9:5]+vc[9:5],1'b0} + (counter>>0);

  wire checkerboard = hc[DOTBITS]^vc[DOTBITS];

  wire regular_hit = (d < r2);

  wire [9:0] delta = d + r2; // Subtracting is nice, but so is adding and other logical ops.

  wire [5:0] white = 6'b11_11_11;

  wire sheen = (hc[DOTBITS-1:2]==4'b101 && vc[DOTBITS-1:2]==4'b101);// ||

  // Not regs:
  reg [5:0] color;
  reg ho;
  assign hit = ho;
  always @(*) begin
    // Pretty dots by default:
    color = hvc;
    // Select where hit calculation comes from:
    case (fmode)
    4'd0:   ho = 0;
    4'd1:   ho = 1;                                         // This effect used to be mode2
    4'd2:   ho = regular_hit;                               // This effect used to be mode0
    4'd3:   ho = (d[10]^d[7]);
    4'd4:   ho = r[3];
    4'd5:   ho = ((d < r2) | d[10]);
    4'd6:   ho = (checkerboard ? 1 : d[7]);
    4'd7:   ho = (checkerboard ? (d < r2) : 0);
    4'd8:   ho = (checkerboard ? (d[10]^d[7]) : (d < r2));
    4'd9:   ho = 0;
    4'd10:  ho = d[DOTBITS+4];
    4'd11:  ho = d[DOTBITS+3];
    4'd12:  ho = d[DOTBITS+2];
    4'd13:  ho = d[DOTBITS+1];
    4'd14:  ho = d[DOTBITS+0];
    // Simple solid-filled dots:
    4'd15:  begin ho = regular_hit; color=white; end                  // Simple dots.
    endcase
  end

  reg [5:0] altcolor;
  always @(*) begin
    case (bmode)
    3'd0:   altcolor = 0;                       // Black.
    3'd1:   altcolor = (delta[9:4]);            // Original baubles.
    3'd2:   altcolor = (delta[9:4] &  r[9:4]);  // Dark blue shimmer.
    3'd3:   altcolor = (delta[9:4] &  d[9:4]);  // Nice darker read/yellow/green shimmer radials.
    3'd4:   altcolor = (delta[9:4] & r2[9:4]);  // Formerly used for mode1 altcolor.
    3'd5:   altcolor = {4'b0000,delta[9:8]};    // Simple blues.
    3'd6:   altcolor = (delta[9:8] + r);        // Purple/blue/green coarse shimmery waves.
    3'd7:   altcolor = {delta[9:8],2'b00,delta[7:6]}; // Red/Blue/Magenta... Well, maybe?
    endcase
  end

  // assign hit = 
  //   (mode==0) ? regular_hit : // Normal combo.
  //   (mode==1) ? regular_hit :
  //   (mode==2) ? 1 : // Smooth baubles.
  //   (mode==3) ? (d[10]^d[7]) : // Good quadrant whipple -- Also good in blue.
  //   (mode==4) ? r[3] :
  //   (mode==5) ? ((d < r2) | d[10]) : // Nicer BG with standard baubles.
  //   (mode==6) ? (checkerboard ? 1 : d[7]) : // Mix of quadrants and smooth baubles. A bit dizzying.
  //   (mode==7) ? (checkerboard ? (d < r2) : 0) :
  //   (mode==8) ? (checkerboard ? (d[10]^d[7]) : (d < r2)) : // Quadrant whipple vs. normal. Pretty, if busy.
  //   (mode==9) ? regular_hit :
  //   /*10..15*/  d[20-mode];
  //   // (mode==1) ? (h[0]^v[0] ? 0 : (d < r*r)) : // Fuzzing, but just meh.
  //   // (mode==9) ? (checkerboard ? 1 : (d < r2)) : // Smooth baubles vs. normal. Nice and relaxed.
  
               //(hc[DOTBITS-1:4]==delta[2:1] && vc[DOTBITS-1:4]==delta[2:1] && (hc[0] ^ vc[0]));

  // wire [5:0] altcolor = 
  //   // (mode==1) ? (delta[9:4] &   d[9:4]) : // Nice darker read/yellow/green shimmer radials.
  //   (mode==1) ? (delta[9:4] & r2[9:4]) : // Nice darker read/yellow/green shimmer radials.

  //   // (mode==9) ? (delta[9:4] & counter[9:4]) : // Lots of different BG variations that emphasize the baubles.
  //   // (mode==9) ? (delta[9:4] & r[9:4]) : // Shimmery dark blue BG pattern really shows off the bright baubles! Nice :)
  //   (mode==9) ? (delta[9:8] + r) : // Purple/blue/green coarse shimmery waves.
  //               // (delta[9:4]); // [9:8] also gives nice blues, and +r is interesting. // &d[9:4] nice anti-tones. // &hvc[9:4] // &counter[9:4] or r or dist2
  //               (delta[9:4] & r[9:4]); // [9:8] also gives nice blues, and +r is interesting. // &d[9:4] nice anti-tones. // &hvc[9:4] // &counter[9:4] or r or dist2

  // // fmode=3, bmode=2    mode3hit + mode3altcolor((delta[9:4] & r[9:4])) is pretty circle shapes! YES.
  // // mode4 meh.
  // // mode5 not bad (circles in traps).
  // // mode6 NO GOOD
  // // mode7 shows alternate columns of baubles on dark blue BG.
  // // mode8 no good
  // // mode10 is JUST the traps.
  // // mode11 is a nice simple version of mode3. "Compass holes"
  // // mode12 is mode11, slightly more complex
  // // mode13 very similar to mode3??
  // // mode14 higher-freq
  // // mode15 NO

  assign rgb = 
    fmode==15 ? (hit?color:0) :
    sheen     ? white :
    hit       ? (delta[9:6]+color) :
                altcolor;  //(dithery & 6'b01_01_01);

endmodule
