// `define CLASSIC_SQ // If defined, use "classic" squaring with real x*x. Else, use a LUT of squares.
`define ROUGH_LUT_6B // Use a LUT of rough approximations (expected to optimise better) for fixed 6-bit-wide squares.
// `define TRUE_SQ // Should LUT square use true negatives?

`ifndef CLASSIC_SQ
`ifdef ROUGH_LUT_6B

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
  output [5:0] rgb
);

  wire [9:0] hc = h+(1<<(DOTBITS-1));
  wire [9:0] vc = v+(1<<(DOTBITS-1));
  // wire [9:0] r = (counter[DOTBITS-2:0] ^ {(DOTBITS-1){counter[DOTBITS-1]}}) * ({2{hc[7]}} ^ hc[6:5]);
  wire [9:0] r = (counter[DOTBITS-2:0] ^ {(DOTBITS-1){counter[DOTBITS-1]}}) + 1 + ({3{hc[8]}} ^ hc[7:5]);

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

  wire hit = d < r2; // Also try: h[0]^v[0] ? 0 : d < r*r; and simply: 1;
  wire [9:0] delta = d + r2; // Subtracting is nice, but so is adding and other logical ops.
  wire [5:0] color = hvc;

  wire [5:0] white = 6'b11_11_11;

  wire sheen = (hc[DOTBITS-1:2]==4'b101 && vc[DOTBITS-1:2]==4'b101);// ||
               //(hc[DOTBITS-1:4]==delta[2:1] && vc[DOTBITS-1:4]==delta[2:1] && (hc[0] ^ vc[0]));

  wire [5:0] altcolor = delta[9:4]; // [9:8] also gives nice blues, and +r is interesting. // &d[9:4] nice anti-tones. // &hvc[9:4] // &counter[9:4] or r or dist2

  assign rgb = 
    sheen ? white :
    hit ? (delta[9:6]+color) : altcolor;  //(dithery & 6'b01_01_01);

endmodule



