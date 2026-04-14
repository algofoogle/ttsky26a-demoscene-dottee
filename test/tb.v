`default_nettype none
`timescale 1ns / 1ps


// `define DUMP_VCD

//   //NOTE: DON'T write VCD file, because it'd be huge!
// `ifdef DUMP_VCD
//   // Dump the signals to a VCD file. You can view it with gtkwave.
//   initial begin
//     $dumpfile("tb.fst");
//     $dumpvars(0, tb);
//     #1;
//   end
// `endif

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

  // Dump the signals to a FST file. You can view it with gtkwave or surfer.
  initial begin
    $dumpfile("tb.fst");
    $dumpvars(0, tb);
    #1;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // Specific outputs for DOTTEE:
  // RrGgBb and H/Vsync pin ordering is per Tiny VGA PMOD
  // (https://tinytapeout.com/specs/pinouts/#vga-output)
  wire [1:0] rr = {uo_out[0],uo_out[4]};
  wire [1:0] gg = {uo_out[1],uo_out[5]};
  wire [1:0] bb = {uo_out[2],uo_out[6]};
  wire [5:0] rgb = {rr,gg,bb}; // Just used by cocotb test bench for convenient checks.
  wire hsync_n    = uo_out[7];
  wire vsync_n    = uo_out[3];


  tt_um_algofoogle_dottee user_project (

      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif

      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

endmodule
