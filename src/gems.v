// `define CLASSIC_SQ

`ifndef CLASSIC_SQ
module sq5b(
  input [4:0] a,
  output reg [9:0] y
);
  always @(*) begin
    case ({4{a[4]}} ^ a[3:0])
    4'd0: y = 0;
    4'd1: y = 1;
    4'd2: y = 2*2;
    4'd3: y = 3*3;
    4'd4: y = 4*4;
    4'd5: y = 5*5;
    4'd6: y = 6*6;
    4'd7: y = 7*7;
    4'd8: y = 8*8;
    4'd9: y = 9*9;
    4'd10: y = 10*10;
    4'd11: y = 11*11;
    4'd12: y = 12*12;
    4'd13: y = 13*13;
    4'd14: y = 14*14;
    4'd15: y = 15*15;
    endcase
  end
endmodule
`endif


module gems #(
  parameter DOTBITS=6
) (
  input [9:0] h,
  input [9:0] v,
  input [9:0] counter,
  output [5:0] rgb
);

  wire signed [9:0] dx = $signed(h[DOTBITS-1:0]);
  wire signed [9:0] dy = $signed(v[DOTBITS-1:0]);

`ifdef CLASSIC_SQ
  wire signed [19:0] dx2 = dx*dx;
  wire signed [19:0] dy2 = dy*dy;
  wire signed [19:0] r2 = r*r;
`else
  wire [9:0] dx2;
  wire [9:0] dy2;
  wire [9:0] r2;

  sq5b sqx(.a(dx[4:0]), .y(dx2));
  sq5b sqy(.a(dy[4:0]), .y(dy2));
  sq5b sqr(.a(r[4:0]), .y(r2));
`endif

  wire [19:0] d = dx2 + dy2;

  // wire [9:0] r = (counter[DOTBITS-2:0] ^ {(DOTBITS-1){counter[DOTBITS-1]}}) * ({2{hc[7]}} ^ hc[6:5]);

  wire [9:0] r = (counter[DOTBITS-2:0] ^ {(DOTBITS-1){counter[DOTBITS-1]}}) + 1 + ({3{hc[8]}} ^ hc[7:5]);

  wire [9:0] hc = h+(1<<(DOTBITS-1));
  wire [9:0] vc = v+(1<<(DOTBITS-1));
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



