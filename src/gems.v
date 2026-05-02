  // wire [5:0] altcolor = delta[9:4]-counter+folded_counter;

module gems #(
  parameter DOTBITS = 6
) (
  input  [9:0] h,
  input  [9:0] v,
  input  [9:0] counter,
  output [5:0] rgb
);

  wire [9:0] hc = h + 10'd32;
  wire [9:0] vc = v + 10'd32;

  wire [5:0] hx = h[5:0];
  wire [5:0] vy = v[5:0];

  wire [5:0] ax = hx[5] ? (~hx + 6'd1) : hx;
  wire [5:0] ay = vy[5] ? (~vy + 6'd1) : vy;

  wire x_lt_y = ax < ay;
  wire [5:0] mn = x_lt_y ? ax : ay;
  wire [5:0] mx = x_lt_y ? ay : ax;

  // Octagon distance approximation: max + min/2
  wire [6:0] d8 = {1'b0, mx} + {2'b00, mn[5:1]};

  wire [4:0] folded_counter =
      counter[4:0] ^ {5{counter[5]}};

  wire [2:0] hband =
      {3{hc[8]}} ^ hc[7:5];

  wire [2:0] wobble =
      hc[8:6] ^
      vc[8:6] ^
      counter[8:6];

  // One deliberately retained square: coarse quadratic radius warp.
  wire [4:0] warp_base =
      hc[9:5] + counter[8:4];

  wire [9:0] warp_sq = warp_base * warp_base;

  wire [2:0] warp = warp_sq[8:6];

  wire [6:0] r_sum =
      {1'b0, folded_counter} +
      7'd1 +
      {4'b0000, hband} +
      {4'b0000, wobble} +
      {4'b0000, warp};

  wire [5:0] r = r_sum[5:0];

  wire hit = d8 < {1'b0, r};

  wire [9:0] delta =
      {3'b000, d8} +
      {4'b0000, r} +
      {counter[3:0], 2'b00};

  // Smoother dynamic colour variation.
  wire [4:0] cell_mix =
      hc[9:5] +
      vc[9:5] +
      {2'b00, counter[8:6]};

  wire [2:0] slow_warp =
      hc[8:6] ^
      vc[8:6] ^
      counter[8:6];

  wire [5:0] color =
      {cell_mix, 1'b0} +
      counter[5:0] +
      {slow_warp, 3'b000} +
      {hc[7:6], vc[7:6]};

  wire sheen =
      (hc[5:2] == 4'b1010) &&
      (vc[5:2] == 4'b1010);

  wire [5:0] altcolor = delta[9:4]-counter+folded_counter;

  assign rgb =
      sheen ? 6'b11_11_11 :
      hit   ? (delta[9:6] + color) :
              altcolor;

endmodule
