module dottee_logo #(
    parameter START_DELAY = 240,
    parameter V_REVEAL_DELAY = 32
) (
    input clk,
    input reset,
    input [9:0] h,
    input [9:0] v,
    input [9:0] counter,
    output logo_hit
);

    // Assumes h is 0..799 and v is 0..524.

    // h == 640
    wire h_eq_640 = h[9] & ~h[8] & h[7] & ~|h[6:0];

    // h == 768
    wire h_eq_768 = h[9] & h[8] & ~|h[7:0];

    wire circle_start = h_eq_640 | h_eq_768;

    // Original: h >= 768 ? 53 : 63
    wire [5:0] circle_radius = (h[9] & h[8]) ? 6'd53 : 6'd63;

    // Original cvo = v - 112.
    // For the circle mirror only low 7 bits matter.
    // -112 mod 128 = +16.
    wire [6:0] cvo7 = v[6:0] + 7'd16;

    wire [5:0] circle_vertical_line =
        cvo7[6] ? cvo7[5:0] : ~cvo7[5:0];

    wire circle_done;
    wire circle_valid;
    wire [5:0] circle_edge;

    circle_edge slow_circle(
        .clk(clk),
        .reset(reset),
        .radius(circle_radius),
        .vertical_line(circle_vertical_line),
        .start(circle_start),
        .done(circle_done),
        .valid(circle_valid),
        .edge_point(circle_edge)
    );

    reg [5:0] circle_outer_edge;

    // h == 700 = 10'b10_1011_1100
    wire h_eq_700 =
        h[9]  & ~h[8] & h[7] & ~h[6] &
        h[5]  &  h[4] & h[3] &  h[2] &
       ~h[1]  & ~h[0];

    always @(posedge clk) begin
        if (reset)
            circle_outer_edge <= 6'd0;
        else if (h_eq_700)
            circle_outer_edge <= circle_edge;
    end

    // Original:
    // cho = h ^ 64;
    // circle_scan = cho[6] ? cho[5:0] : ~cho[5:0];
    //
    // Equivalent simplification:
    wire [5:0] circle_scan = h[6] ? ~h[5:0] : h[5:0];

    wire in_outer_circle = circle_scan > circle_outer_edge;
    wire in_inner_circle = circle_scan > circle_edge;

    wire in_circle = circle_valid && in_outer_circle && !in_inner_circle;

    // Original side_clip: h >= 32 && h < 608
    wire [4:0] h32 = h[9:5];
    wire side_clip = |h32 && (h32 < 5'd19);

    // Original:
    // cvo[9:6] == 1 -> v = 176..239
    // cvo[9:6] == 2 -> v = 240..303
    wire logo_upper_half = (v >= 10'd176) && (v < 10'd240);
    wire logo_lower_half = (v >= 10'd240) && (v < 10'd304);

    wire in_logo = (logo_upper_half || logo_lower_half) && side_clip;

    wire in_tt_logo = (h[9:8] == 2'b01);
    wire [7:0] hx = h[7:0];

    // Original: h < 42
    wire d_left_bar =
        (h[9:6] == 4'd0) &&
        (h[5:0] < 6'd42);

    // Original:
    // cvo > 91  -> v > 203
    // cvo <=108 -> v <=220
    // h < 332   -> in TT logo, hx < 76
    wire tt_upper_bar =
        in_tt_logo &&
        (hx < 8'd76) &&
        (v > 10'd203) &&
        (v <= 10'd220);

    // Original:
    // cvo > 122 -> v > 234
    // cvo < 140 -> v < 252
    // h > 300   -> hx > 44
    // h < 361   -> hx < 105
    wire tt_lower_bar =
        in_tt_logo &&
        (hx > 8'd44) &&
        (hx < 8'd105) &&
        (v > 10'd234) &&
        (v < 10'd252);

    // Original:
    // cvo > 91  -> v > 203
    // cvo <=151 -> v <=263
    // h > 293   -> hx > 37
    // h < 313   -> hx < 57
    wire tt_upper_post =
        in_tt_logo &&
        (hx > 8'd37) &&
        (hx < 8'd57) &&
        (v > 10'd203) &&
        (v <= 10'd263);

    // Original:
    // cvo > 122 -> v > 234
    // h > 323   -> hx > 67
    // h < 343   -> hx < 87
    wire tt_lower_post =
        in_tt_logo &&
        (hx > 8'd67) &&
        (hx < 8'd87) &&
        (v > 10'd234);

    wire inclusions =
        in_outer_circle &&
        (
            d_left_bar     ||
            tt_upper_bar   ||
            tt_lower_bar   ||
            tt_upper_post  ||
            tt_lower_post
        );

    // Original:
    // h < 276 inside TT logo -> hx < 20
    // cvo > 108 -> v > 220
    // cvo < 116 -> v < 228
    wire excl_tt_gap_1 =
        in_tt_logo &&
        (hx < 8'd20) &&
        (v > 10'd220) &&
        (v < 10'd228);

    // Original:
    // h > 342 && h < 349 -> hx > 86 && hx < 93
    // cvo > 164 -> v > 276
    wire excl_tt_gap_2 =
        in_tt_logo &&
        (hx > 8'd86) &&
        (hx < 8'd93) &&
        (v > 10'd276);

    wire excl_lower_slot =
        (h32 == 5'd15) &&
        logo_lower_half;

    wire exclusions =
        excl_tt_gap_1 ||
        excl_tt_gap_2 ||
        excl_lower_slot;

    // Original:
    // cvo > 123 && cvo < 133 -> v > 235 && v < 245
    // cho[9:7] >= 3. Bit 6 flip does not affect [9:7].
    wire h_ge_384 = h[9] | (h[8] & h[7]);

    wire overlaid =
        in_outer_circle &&
        (v > 10'd235) &&
        (v < 10'd245) &&
        h_ge_384;

    assign logo_hit =
        in_logo &&
        (
            ((in_circle || inclusions) && !exclusions) ||
            overlaid
        );

endmodule