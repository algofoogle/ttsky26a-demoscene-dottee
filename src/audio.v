/*
 * Copyright (c) 2026 Anton Maurovic
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// `define OCTAVE_DOWN 1

module audio #(
    parameter B = 5, // Internal bit depth of audio samples. 10 excellent. 8 good. 6 some harmonics. 5 workable. 4 just passable. 3 gritty.
    parameter SUB = 9, // Sub-resolution of the voice phase accumulator. 1+B+SUB is the total phase bit depth: Larger gives more tonal precision. 1+4+8 is minimum.
    parameter FS1K = 31468750 // Sampling rate * 1000, in Hz. Derived from 25175000/800 (VGA horizontal frequency).
) (
    input clk,
    input rst_n,
    input [11:0] frame_counter,
    input [9:0] h,
    input [9:0] v,
    input sample_clk,
    output dac_out,
    output [B-1:0] sample_out
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

    localparam [3:0] NC     = 0;
    localparam [3:0] NCs    = 1;
    localparam [3:0] ND     = 2;
    localparam [3:0] NDs    = 3;
    localparam [3:0] NE     = 4;
    localparam [3:0] NF     = 5;
    localparam [3:0] NFs    = 6;
    localparam [3:0] NG     = 7;
    localparam [3:0] NGs    = 8;
    localparam [3:0] NA     = 9;
    localparam [3:0] NAs    = 10;
    localparam [3:0] NB     = 11;

    function [B+SUB:0] note_map;
        input [3:0] note;
        input signed [2:0] oct;
        begin
            case (note)
            // NC:     note_map = PC   <<  oct;
            // NCs:    note_map = PCs  <<  oct;
            // ND:     note_map = PD   <<  oct;
            // NDs:    note_map = PDs  <<  oct;
            // NE:     note_map = PE   <<  oct;
            // NF:     note_map = PF   <<  oct;
            // NFs:    note_map = PFs  <<  oct;
            // NG:     note_map = PG   <<  oct;
            // NGs:    note_map = PGs  <<  oct;
            // NA:     note_map = PA   <<  oct;
            // NAs:    note_map = PAs  <<  oct;
            // NB:     note_map = PB   <<  oct;

            // Notes are remapped here to be closer to A440 tuning:
            NC:     note_map = PA   <<  (oct+0);
            NCs:    note_map = PAs  <<  (oct+0);
            ND:     note_map = PB   <<  (oct+0);
            NDs:    note_map = PC   <<  (oct+1);
            NE:     note_map = PCs  <<  (oct+1);
            NF:     note_map = PD   <<  (oct+1);
            NFs:    note_map = PDs  <<  (oct+1);
            NG:     note_map = PE   <<  (oct+1);
            NGs:    note_map = PF   <<  (oct+1);
            NA:     note_map = PFs  <<  (oct+1);
            NAs:    note_map = PG   <<  (oct+1);
            NB:     note_map = PGs  <<  (oct+1);
            default:note_map = 0;
            endcase
`ifdef OCTAVE_DOWN
            note_map = note_map >> `OCTAVE_DOWN;
`endif//OCTAVE_DOWN
        end
    endfunction

    // The whole demo is made up of 16 musical bars:
    wire [3:0] musbar = frame_counter[11:8];


    // Phase increment (frequency factor) chosen for the notes we want:
    reg [B+SUB:0] pinc; // False reg.
    always @(*) begin
        pinc = 0; // Silence by default.

        // Simple 2 beats per first 2 bar:
        casez(frame_counter[6:3])
        4'd0:       pinc = note_map(NC,     1);
        // 1
        4'd2:       pinc = note_map(NC,     1);
        // 3..15
        endcase

        // Then add 3 more beats for the next 2 bars:
        if (musbar>0) begin
            casez(frame_counter[6:3])
            // 0..5
            4'd6:       pinc = note_map(NC,     1);
            // 7..13
            4'd13:      pinc = note_map(NC,     1);
            // 14
            4'd15:      pinc = note_map(NC,     1);
            endcase
        end

        // Then add other flourishes after that:
        if (musbar>1) begin
            casez(frame_counter[6:3])
            // 0
            4'd1:       pinc = note_map(NC,     2);
            // 2
            4'd3:       pinc = note_map(NG,     1);
            4'd4:       pinc = note_map(NAs,    1);
            4'd5:       pinc = note_map(NC,     2);
            // 6
            4'd7:       pinc = note_map(NAs,    1);
            4'd8:       pinc = note_map(NG,     1);
            4'd9:       pinc = note_map(NAs,    1);
            4'd10:      pinc = note_map(NC,     2);
            4'd11:      pinc = note_map(NAs,    1);
            4'd12:      pinc = note_map(NG,     1);
            // 13
            4'd14:      pinc = note_map(NG,     1);
            // 15
            endcase
        end

        if (musbar<12 || frame_counter[1])
            pinc = pinc << 1; // Bump up an extra octave in the early bars.
    end

    // False regs:
    reg p2en;
    reg [B+SUB:0] p2; 
    always @(*) begin
        p2 = 0;
        p2en = 0;
        if (musbar>=4) begin
            p2en = 1;
            casez(frame_counter[9:6])
            4'd0:   p2 = note_map(NC, 0);
            4'd1:   p2 = note_map(NC, 0);
            4'd2:   p2 = note_map(NAs, -1);
            4'd3:   p2 = note_map(NAs, -1);
            4'd4:   p2 = note_map(NDs, 0);
            4'd5:   p2 = note_map(NDs, 0);
            4'd6:   p2 = note_map(NF, 0);
            4'd7:   p2 = note_map(NF, 0);

            4'd8:   p2 = note_map(NC, 0);
            4'd9:   p2 = note_map(NC, 0);
            4'd10:  p2 = note_map(NAs, -1);
            4'd11:  p2 = note_map(NAs, -1);
            4'd12:  p2 = note_map(NDs, -1);
            4'd13:  p2 = note_map(NDs, -1);
            4'd14:  p2 = note_map(NF, -1);
            4'd15:  p2 = note_map(NF, -1);
            endcase
        end
        if (p2 != 0)
            p2 = p2 + {{B+SUB{1'b0}}, frame_counter[2]}; // Vibrato.

        if (musbar<8) begin
            if (frame_counter[4]) begin
                p2 >>= 1;
            end
        end else if (musbar<12) begin
            if (frame_counter[6]) begin
                p2 >>= 1;
            end
        end else begin
            if (frame_counter[2]) begin
                p2 >>= 1;
            end
        end
    end

    wire [B:0] phase1;
    phase_acc #(
        .B(B+1), // Extra bit is sign for wave folding.
        .SUB(SUB)
    ) v1 (
        .clk(clk),
        .rst_n(rst_n),
        .trigger(sample_clk), // Go high for 1 clk whenever we must accumulate another phase increment.
        .inc(pinc),
        .sample_out(phase1)
    );

    wire [B:0] phase2;
    phase_acc #(
        .B(B+1), // Extra bit is sign for wave folding.
        .SUB(SUB)
    ) v2 (
        .clk(clk),
        .rst_n(rst_n),
        .trigger(sample_clk), // Go high for 1 clk whenever we must accumulate another phase increment.
        .inc(p2),
        .sample_out(phase2)
    );


    // Generate a signed triangle wave, by folding the phase sawtooth ramp:
    function signed [B-1:0] tr_map;
        input [B:0] phase;
        begin
            tr_map = (({B{phase[B]}} ^ phase[B-1:0]) + (1<<(B-1))); //NOTE: midpoint bias added for making this signed. Can we avoid that?
        end
    endfunction

    // Generate a signed square wave from the phase:
    function signed [B-1:0] sq_map;
        input [B:0] phase;
        begin
            sq_map = ({B{phase[B]}} ^ (1<<(B-1)));
        end
    endfunction

    // Attenuates a signed sample by a given attenuation factor (right-shift amount):
    function signed [B-1:0] decayed_sample;
        input signed [B-1:0] sample;
        input [2:0] afactor;
        begin
            if (afactor>=B)
                decayed_sample = 0; // Mute.
            else
                decayed_sample = sample >>> afactor;
        end
    endfunction

    // Exponential attenuation factor:
    wire [2:0] decay = frame_counter[3:1]; // Sort of pan pipe effect at Q5.9 when decay is only fc[1:0].
    wire [2:0] cross_decay = {3{frame_counter[6]}} ^ frame_counter[5:3];
    // wire [2:0] decay = frame_counter[3:1]; // Sort of pan pipe effect at Q5.9 when decay is only fc[1:0].
    // wire [2:0] cross_decay = {3{frame_counter[6]}} ^ frame_counter[5:3];

    wire signed [B-1:0] voice1 = (pinc==0) ? 0 : decayed_sample(tr_map(phase1), decay);
    wire signed [B-1:0] voice2 =
        (~p2en)     ?   0 :
        musbar<8    ?   (tr_map(phase2)>>>1) :
        musbar<12   ?   (sq_map(phase2)>>>cross_decay) + (tr_map(phase2)>>>~cross_decay) :
                        (sq_map(phase2)>>>cross_decay) + (tr_map(phase2)>>>((~cross_decay[2:1])));
    // wire signed [B-1:0] sample = (h < frame_counter) ? (h[B-1:0]+v+frame_counter) : mixer[B:1];

    wire [B-1:0] t = frame_counter[B-1:0];

    // 5432
    // 0000: drum
    // 0001: -
    // 0010: -
    // 0011: -
    // 0100: hat
    // 0101: -
    // 0110: -
    // 0111: -
    // 1000: hat
    // 1001: -
    // 1010: -
    // 1011: -
    // 1100: hat
    // 1101: -
    // 1110: -
    // 1111: -
    reg [9:0] b;
    reg [3:0] a; // Attenuation.
    always @(*) begin
        a = 0;
        b = 0;
        if (frame_counter[5:2]==4'b0000) begin
            // Drum:
            b = (v>>(5+frame_counter[2:1]));
            a = frame_counter[2:0]; // Attenuation.
        end else if (frame_counter[3:2]==2'b00) begin
            // Hi-hat (longer tail):
            b = v;
            a = (frame_counter[4] && musbar<6) ? 4'b1111 : (frame_counter[2:0]+1); // Attenuation.
        end
    end
    
    wire [B-1:0] noise = ({b[7],1'b0,b[1],1'b0,b[2],1'b0} + (b<<t[1:0]) - (b[8:3]>>t[1:0])) ^ (b+t) ^ t;  //(h ^ v) + {B{t[0]}};

    wire [5:0] nn = noise + {noise,1'b0};

    wire nn2 = nn >= 32;

    wire [B-1:0] drums = ({6{nn2}}>>a);

    wire drums_en = (musbar>=3);
    wire v2_amp = (musbar<8); // voice2 is louder only for the 1st half of the music. Avoids clipping and sounds better in general.

    wire signed [B+1:0] mixer = 
        drums_en ?  ((voice1<<1) + (voice2<<v2_amp) + $signed({drums})) :
                    ((voice1<<1) + (voice2<<1));
                    
    wire signed [B-1:0] sample = mixer[B+1:2];

    assign sample_out = sample;


    sigmadelta_dac #(.B(B)) dac(
        .clk(clk),
        .rst_n(rst_n),
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
    input rst_n,
    input trigger,
    input [MSB:0] inc,
    output [B-1:0] sample_out
);
    reg [MSB:0] phase;
    assign sample_out = phase[MSB:SUB];
    always @(posedge clk) begin
        if (~rst_n)
            phase <= 0;
        else if (trigger)
            phase <= phase + {inc};
    end
endmodule


module sigmadelta_dac #(
    parameter B = 5 // Sample bit resolution.
) (
    input  wire clk,
    input  wire rst_n,
    input  wire [B-1:0] sample_in,
    output reg  dac_out //NOTE: Does this actually need to be registered??
);
    reg  [B-1:0] sd_err;
    wire [B:0] sd_sum = {1'b0, sd_err} + {1'b0, sample_in};

    always @(posedge clk) begin
        if (~rst_n) begin
            sd_err  <= 0;
            dac_out <= 0;
        end else begin
            sd_err  <= sd_sum[B-1:0];
            dac_out <= sd_sum[B];
        end
    end
endmodule
