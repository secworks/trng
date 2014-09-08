//======================================================================
//
// tb_csprng.v
// -----------
// Testbench for the csprng module in the trng.
//
//
// Author: Joachim Strombergson
// Copyright (c) 2014, Secworks Sweden AB
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or
// without modification, are permitted provided that the following
// conditions are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

//------------------------------------------------------------------
// Simulator directives.
//------------------------------------------------------------------
`timescale 1ns/100ps


//------------------------------------------------------------------
// Test module.
//------------------------------------------------------------------
module tb_csprng();

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter DEBUG     = 1;

  parameter CLK_HALF_PERIOD = 1;
  parameter CLK_PERIOD      = 2 * CLK_HALF_PERIOD;


  //----------------------------------------------------------------
  // Register and Wire declarations.
  //----------------------------------------------------------------
  reg [31 : 0] cycle_ctr;
  reg [31 : 0] error_ctr;
  reg [31 : 0] tc_ctr;

  reg           tb_clk;
  reg           tb_reset_n;
  reg           tb_debug_mode;
  reg [4 : 0]   tb_num_rounds;
  reg [63 : 0]  tb_num_blocks;
  reg           tb_seed;
  reg           tb_enable;
  wire          tb_ready;
  wire          tb_error;
  reg           tb_seed_syn;
  reg [511 : 0] tb_seed_data;
  wire          tb_seed_ack;
  wire          tb_rnd_syn;
  wire [31: 0]  tb_rnd_data;
  reg           tb_rnd_ack;


  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  trng_csprng dut(
                  .clk(tb_clk),
                  .reset_n(tb_reset_n),

                  .debug_mode(tb_debug_mode),
                  .num_rounds(tb_num_rounds),
                  .num_blocks(tb_num_blocks),
                  .seed(tb_seed),
                  .enable(tb_enable),
                  .ready(tb_ready),
                  .error(tb_error),

                  .seed_syn(tb_seed_syn),
                  .seed_data(tb_seed_data),
                  .seed_ack(tb_seed_ack),

                  .rnd_syn(tb_rnd_syn),
                  .rnd_data(tb_rnd_data),
                  .rnd_ack(tb_rnd_ack)
                 );


  //----------------------------------------------------------------
  // clk_gen
  //
  // Always running clock generator process.
  //----------------------------------------------------------------
  always
    begin : clk_gen
      #CLK_HALF_PERIOD;
      tb_clk = !tb_clk;
    end // clk_gen


  //----------------------------------------------------------------
  // sys_monitor()
  //
  // An always running process that creates a cycle counter and
  // conditionally displays information about the DUT.
  //----------------------------------------------------------------
  always
    begin : sys_monitor
      cycle_ctr = cycle_ctr + 1;
      #(CLK_PERIOD);
      if (DEBUG)
        begin
          dump_dut_state();
        end
    end


  //----------------------------------------------------------------
  // dump_dut_state()
  //
  // Dump the state of the dump when needed.
  //----------------------------------------------------------------
  task dump_dut_state();
    begin
      $display("State of DUT");
      $display("------------");
      $display("Inputs:");
      $display("debug_mode = 0x%01x, seed = 0x%01x, enable = 0x%01x",
               dut.debug_mode, dut.seed, dut.enable);
      $display("ready = 0x%01x, error = 0x%01x",
               dut.ready, dut.error);
      $display("num_rounds = 0x%02x, num_blocks = 0x%016x",
               dut.num_rounds, dut.num_blocks);
      $display("seed_syn = 0x%01x, seed_ack = 0x%01x, seed_data = 0x%064x",
               dut.seed_syn, dut.seed_ack, dut.seed_data);
      $display("");

      $display("Internal states:");
      $display("cipher_key   = 0x%032x", dut.cipher_key_reg);
      $display("cipher_iv    = 0x%08x, cipher_ctr = 0x%08x",
               dut.cipher_iv_reg, dut.cipher_ctr_reg);
      $display("cipher_block = 0x%064x", dut.cipher_block_reg);
      $display("csprng_ctrl  = 0x%02x", dut.csprng_ctrl_reg);
      $display("");
      $display("Cipher states:");
      $display("cipher init: 0x%01x, cipher next: 0x%01x",
               dut.chacha.init, dut.chacha.next);
      $display("cipher ready: 0x%01x, cipher data out valud: 0x%01x",
               dut.chacha.ready, dut.chacha.data_out_valid);
      $display("cipher data out: 0x%064x", dut.chacha.data_out);
      $display("");

      $display("Outputs:");
      $display("rnd_syn = 0x%01x, rnd_ack = 0x%01x, rnd_data = 0x%08x",
               dut.rnd_syn, dut.rnd_ack, dut.rnd_data);
      $display("");
    end
  endtask // dump_dut_state


  //----------------------------------------------------------------
  // reset_dut()
  //
  // Toggle reset to put the DUT into a well known state.
  //----------------------------------------------------------------
  task reset_dut();
    begin
      $display("*** Toggle reset.");
      tb_reset_n = 0;

      #(2 * CLK_PERIOD);
      tb_reset_n = 1;
      $display("");
    end
  endtask // reset_dut


  //----------------------------------------------------------------
  // display_test_results()
  //
  // Display the accumulated test results.
  //----------------------------------------------------------------
  task display_test_results();
    begin
      if (error_ctr == 0)
        begin
          $display("*** All %02d test cases completed successfully", tc_ctr);
        end
      else
        begin
          $display("*** %02d tests completed - %02d test cases did not complete successfully.",
                   tc_ctr, error_ctr);
        end
    end
  endtask // display_test_results


  //----------------------------------------------------------------
  // init_sim()
  //
  // Initialize all counters and testbed functionality as well
  // as setting the DUT inputs to defined values.
  //----------------------------------------------------------------
  task init_sim();
    begin
      cycle_ctr     = 0;
      error_ctr     = 0;
      tc_ctr        = 0;

      tb_clk        = 0;
      tb_reset_n    = 1;
      tb_debug_mode = 0;
      tb_num_rounds = 5'h00;
      tb_num_blocks = 64'h0000000000000000;
      tb_seed       = 0;
      tb_enable     = 0;
      tb_seed_syn   = 0;
      tb_seed_data  = {16{32'h00000000}};
      tb_rnd_ack    = 0;
    end
  endtask // init_sim


  //----------------------------------------------------------------
  // tc1_test_init_cipher()
  //
  // TC1: Test that the DUT automatically starts initialize when
  // enable is set.
  //----------------------------------------------------------------
  task tc1_test_init_cipher();
    begin
      $display("*** TC1: Test automatic init of cipher started.");
      tb_seed_syn   = 1;
      tb_seed_data  = {8{64'haaaaaaaa55555555}};
      tb_enable     = 1;

      #(200 * CLK_PERIOD);

      $display("*** TC1: Test automatic init of cipher done.");

    end
  endtask // tc1_test_init_cipher


  //----------------------------------------------------------------
  // csprng_test
  //
  // The main test functionality.
  //----------------------------------------------------------------
  initial
    begin : csprng_test

      $display("   -= Testbench for csprng started =-");
      $display("    ================================");
      $display("");

      init_sim();
      dump_dut_state();
      reset_dut();
      dump_dut_state();

      // Test code goes here.
      tc1_test_init_cipher();

      display_test_results();

      $display("");
      $display("*** CSPRNG simulation done. ***");
      $finish;
    end // csprng_test
endmodule // tb_csprng

//======================================================================
// EOF tb_csprng.v
//======================================================================
