/*
 * Copyright (c) 2026 Anton Maurovic
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module audio #(
    parameter B = 5, // Internal bit depth of audio samples. 10 excellent. 8 good. 6 some harmonics. 5 workable. 4 just passable. 3 gritty.
    parameter SUB = 9, // Sub-resolution of the voice phase accumulator. 1+B+SUB is the total phase bit depth: Larger gives more tonal precision. 1+4+8 is minimum.
    parameter FS1K = 31468750 // Sampling rate * 1000, in Hz. Derived from 25175000/800 (VGA horizontal frequency).
) (
    input clk,
    input reset,
    input [11:0] frame_counter,
    input sample_clk,
    output dac_out
);

    // Tuning based on G1=59.94Hz (making it possible for us to tune based on VSYNC):
    // C2 = G1*2^(5/12) ~= 59.94*1.33484 ~= 80.010301Hz
    // Sampling rate (based on sample_clk) is (25175000/800)=31468.75Hz
    // Hence, each sample is a fractional slice:
    // n = 80.010301/31468.75 ~= 0.0025425
    // This becomes a portion of the full phase ramp range of 2^(1+B+SUB),
    // which for the default parameters is 32768.
    // Hence, the frequency factor is C2~=0.0020179*8192~=83.31 => round to 83.
    //NOTE: These numbers are huge to maintain integer precision before they're scaled/rounded down.
    //                       f*1E6           RampRange     Fs*1000 Round /1000
    localparam [63:0] PC  = (( 80_010_301 * (2**(1+B+SUB)) / FS1K)+500)/1000;
    localparam [63:0] PCs = (( 84_767_961 * (2**(1+B+SUB)) / FS1K)+500)/1000;
    localparam [63:0] PD  = (( 89_808_526 * (2**(1+B+SUB)) / FS1K)+500)/1000;
    localparam [63:0] PDs = (( 95_148_819 * (2**(1+B+SUB)) / FS1K)+500)/1000;
    localparam [63:0] PE  = ((100_806_662 * (2**(1+B+SUB)) / FS1K)+500)/1000;
    localparam [63:0] PF  = ((106_800_938 * (2**(1+B+SUB)) / FS1K)+500)/1000;
    localparam [63:0] PFs = ((113_151_653 * (2**(1+B+SUB)) / FS1K)+500)/1000;
    localparam [63:0] PG  = ((119_880_000 * (2**(1+B+SUB)) / FS1K)+500)/1000; // Freq const is 2*59.94 (1 octave higher), but actual freq won't be exact.
    localparam [63:0] PGs = ((127_008_436 * (2**(1+B+SUB)) / FS1K)+500)/1000;
    localparam [63:0] PA  = ((134_560_750 * (2**(1+B+SUB)) / FS1K)+500)/1000;
    localparam [63:0] PAs = ((142_562_149 * (2**(1+B+SUB)) / FS1K)+500)/1000;
    localparam [63:0] PB  = ((151_039_335 * (2**(1+B+SUB)) / FS1K)+500)/1000;

    initial begin
        $display("Note frequency factors (phase increments):");
        $display("C:",   PC    );
        $display("C#:",  PCs   );
        $display("D:",   PD    );
        $display("D#:",  PDs   );
        $display("E:",   PE    );
        $display("F:",   PF    );
        $display("F#:",  PFs   );
        $display("G:",   PG    );
        $display("G#:",  PGs   );
        $display("A:",   PA    );
        $display("A#:",  PAs   );
        $display("B:",   PB    );
    end;

    // Phase increment (frequency factor) chosen for the notes we want:
    reg [B+SUB:0] pinc; // False reg.
    always @(*) begin
        pinc = 0; // Silence by default.
        casez(frame_counter[7:2])
        6'd0,
        6'd1:   pinc = PC<<1;
        // Rest: 4
        6'd6:   pinc = PC<<1;
        // Rest: 1
        6'd8,
        6'd9:   pinc = PC<<1;
        // Rest: 2
        6'd12,
        6'd13:  pinc = PAs;
        // Rest: 2
        6'd16,
        6'd17:  pinc = PG;
        // Rest: 2
        6'd20,
        6'd21:  pinc = PAs;
        // Rest: 2
        6'd24,
        6'd25:  pinc = PC<<1;
        // Rest: 2
        6'd28,
        6'd29:  pinc = PDs<<1;
        // Rest: 2
        6'd32,
        6'd33:  pinc = PAs;
        // Rest: 4
        6'd38,
        6'd39:  pinc = PD<<1;
        6'd40,
        6'd41:  pinc = PF<<1;
        // Rest: 2
        6'd44,
        6'd45:  pinc = PD<<1;
        // Rest: 2
        6'd48,
        6'd49:  pinc = PAs;
        6'd50,
        6'd51:  pinc = PD<<1;
        6'd52,
        6'd53:  pinc = PF<<1;
        6'd54,
        6'd55:  pinc = PD<<1;
        6'd56,
        6'd57:  pinc = PAs;
        6'd58,
        6'd59:  pinc = PD<<1;
        6'd60,
        6'd61:  pinc = PF<<1;
        6'd62,
        6'd63:  pinc = PD<<1;
        endcase
        pinc = pinc << 1; // Bump up an extra octave.
    end


    wire [B:0] phase;
    phase_acc #(
        .B(B+1), // Extra bit is sign for wave folding.
        .SUB(SUB)
    ) v1 (
        .clk(clk),
        .reset(reset),
        .trigger(sample_clk), // Go high for 1 clk whenever we must accumulate another phase increment.
        .inc(pinc),
        .sample_out(phase)
    );

    // Generate a signed triangle wave, by folding the phase sawtooth ramp:
    wire signed [B-1:0] tr_sample = (({B{phase[B]}} ^ phase[B-1:0]) + (1<<(B-1))); //NOTE: midpoint bias added for making this signed. Can we avoid that?

    wire signed [B-1:0] sample = tr_sample; //mixed_sample[B:1];

    sigmadelta_dac #(.B(B)) dac(
        .clk(clk),
        .reset(reset),
        .sample_in(sample+(1<<(B-1))), // signed => unsigned.
        .dac_out(dac_out)
    );

endmodule


module phase_acc #(
    parameter B = 5,
    parameter SUB = 8,
    parameter MSB = B+SUB-1
) (
    input clk,
    input reset,
    input trigger,
    input [MSB:0] inc,
    output [B-1:0] sample_out
);
    reg [MSB:0] phase;
    assign sample_out = phase[MSB:SUB];
    always @(posedge clk) begin
        if (reset)
            phase <= 0;
        else if (trigger)
            phase <= phase + {inc};
    end
endmodule


module sigmadelta_dac #(
    parameter B = 5 // Sample bit resolution.
) (
    input  wire clk,
    input  wire reset,
    input  wire [B-1:0] sample_in,
    output reg  dac_out //NOTE: Does this actually need to be registered??
);
    reg  [B-1:0] sd_err;
    wire [B:0] sd_sum = {1'b0, sd_err} + {1'b0, sample_in};

    always @(posedge clk) begin
        if (reset) begin
            sd_err  <= 0;
            dac_out <= 0;
        end else begin
            sd_err  <= sd_sum[B-1:0];
            dac_out <= sd_sum[B];
        end
    end
endmodule
