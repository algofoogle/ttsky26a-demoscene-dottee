module circle_edge(
    input clk,
    input reset,
    input [5:0] radius,
    input [5:0] vertical_line,
    input start,

    output done,
    output valid,
    output [5:0] edge_point
);

    reg [5:0] x;
    reg [5:0] y;
    reg signed [7:0] d;

    wire [5:0] target_y = ~vertical_line;

    wire valid_i = target_y <= radius;
    wire top_octant_hit = y <= target_y;
    wire low_octant_hit = x >= target_y;

    assign valid = valid_i;
    assign done  = !valid_i || top_octant_hit || low_octant_hit;

    assign edge_point =
        !valid_i       ? 6'd0 :
        low_octant_hit ? radius - y :
                         radius - x;

    always @(posedge clk) begin
        if (reset) begin
            x <= 6'd0;
            y <= 6'd0;
            d <= 8'sd0;
        end else if (start) begin
            x <= 6'd0;
            y <= radius;
            d <= 8'sd1 - $signed({2'b00, radius});
        end else if (!done) begin
            x <= x + 6'd1;

            if (d[7]) begin
                d <= d + $signed({1'b0, x, 1'b0}) + 8'sd3;
            end else begin
                y <= y - 6'd1;
                d <= d
                   + $signed({1'b0, x, 1'b0})
                   - $signed({1'b0, y, 1'b0})
                   + 8'sd5;
            end
        end
    end

endmodule