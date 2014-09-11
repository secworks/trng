//======================================================================
//
// trng_mixer.v
// ------------
// Mixer for the TRNG.
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

module trng_mixer(
                  // Clock and reset.
                  input wire           clk,
                  input wire           reset_n,

                  // Controls.
                  input wire           enable,
                  input wire           more_seed,

                  input wire           entropy0_enabled,
                  input wire           entropy0_syn,
                  output wire          entropy0_ack,

                  input wire           entropy1_enabled,
                  input wire           entropy1_syn,
                  output wire          entropy1_ack,

                  input wire           entropy2_enabled,
                  input wire           entropy2_syn,
                  output wire          entropy2_ack,

                  output wire [511 : 0] seed_data,
                  output wire           seed_syn,
                  input wire            seed_ack
                 );


  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter MODE_SHA_512 = 2'h3;

  parameter CTRL_IDLE    = 4'h0;
  parameter CTRL_COLLECT = 4'h1;
  parameter CTRL_MIX     = 4'h2;
  parameter CTRL_SYN     = 4'h3;
  parameter CTRL_ACK     = 4'h4;
  parameter CTRL_CANCEL  = 4'hf;


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [31 : 0] block00_reg;
  reg [31 : 0] block00_we;
  reg [31 : 0] block01_reg;
  reg [31 : 0] block01_we;
  reg [31 : 0] block02_reg;
  reg [31 : 0] block02_we;
  reg [31 : 0] block03_reg;
  reg [31 : 0] block03_we;
  reg [31 : 0] block04_reg;
  reg [31 : 0] block04_we;
  reg [31 : 0] block05_reg;
  reg [31 : 0] block05_we;
  reg [31 : 0] block06_reg;
  reg [31 : 0] block06_we;
  reg [31 : 0] block07_reg;
  reg [31 : 0] block07_we;
  reg [31 : 0] block08_reg;
  reg [31 : 0] block08_we;
  reg [31 : 0] block09_reg;
  reg [31 : 0] block09_we;
  reg [31 : 0] block10_reg;
  reg [31 : 0] block10_we;
  reg [31 : 0] block11_reg;
  reg [31 : 0] block11_we;
  reg [31 : 0] block12_reg;
  reg [31 : 0] block12_we;
  reg [31 : 0] block13_reg;
  reg [31 : 0] block13_we;
  reg [31 : 0] block14_reg;
  reg [31 : 0] block14_we;
  reg [31 : 0] block15_reg;
  reg [31 : 0] block15_we;
  reg [31 : 0] block16_reg;
  reg [31 : 0] block16_we;
  reg [31 : 0] block17_reg;
  reg [31 : 0] block17_we;
  reg [31 : 0] block18_reg;
  reg [31 : 0] block18_we;
  reg [31 : 0] block19_reg;
  reg [31 : 0] block19_we;
  reg [31 : 0] block20_reg;
  reg [31 : 0] block20_we;
  reg [31 : 0] block21_reg;
  reg [31 : 0] block21_we;
  reg [31 : 0] block22_reg;
  reg [31 : 0] block22_we;
  reg [31 : 0] block23_reg;
  reg [31 : 0] block23_we;
  reg [31 : 0] block24_reg;
  reg [31 : 0] block24_we;
  reg [31 : 0] block25_reg;
  reg [31 : 0] block25_we;
  reg [31 : 0] block26_reg;
  reg [31 : 0] block26_we;
  reg [31 : 0] block27_reg;
  reg [31 : 0] block27_we;
  reg [31 : 0] block28_reg;
  reg [31 : 0] block28_we;
  reg [31 : 0] block29_reg;
  reg [31 : 0] block29_we;
  reg [31 : 0] block30_reg;
  reg [31 : 0] block30_we;
  reg [31 : 0] block31_reg;
  reg [31 : 0] block31_we;

  reg [3 : 0] mixer_ctrl_reg;
  reg [3 : 0] mixer_ctrl_new;
  reg         mixer_ctrl_we;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg             muxed_entropy;
  reg             update_block;

  reg             hash_init;
  reg             hash_next;

  wire [1023 : 0] hash_block;
  wire            hash_ready;
  wire [511 : 0]  hash_digest;
  wire            hash_digest_valid;


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign seed_data = hash_digest;


  //----------------------------------------------------------------
  // core instantiation.
  //----------------------------------------------------------------
  sha512_core hash(
                   .clk(clk),
                   .reset_n(reset_n),

                   .init(hash_init),
                   .next(hash_next),
                   .mode(MODE_SHA_512),

                   .block(hash_block),

                   .ready(hash_ready),
                   .digest(hash_digest),
                   .digest_valid(hash_digest_valid)
                  );


  //----------------------------------------------------------------
  // reg_update
  //
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with synchronous
  // active low reset. All registers have write enable.
  //----------------------------------------------------------------
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        begin
          block00_reg <= 32'h00000000;
          block01_reg <= 32'h00000000;
          block02_reg <= 32'h00000000;
          block03_reg <= 32'h00000000;
          block04_reg <= 32'h00000000;
          block05_reg <= 32'h00000000;
          block06_reg <= 32'h00000000;
          block07_reg <= 32'h00000000;
          block08_reg <= 32'h00000000;
          block09_reg <= 32'h00000000;
          block10_reg <= 32'h00000000;
          block11_reg <= 32'h00000000;
          block12_reg <= 32'h00000000;
          block13_reg <= 32'h00000000;
          block14_reg <= 32'h00000000;
          block15_reg <= 32'h00000000;
          block16_reg <= 32'h00000000;
          block17_reg <= 32'h00000000;
          block18_reg <= 32'h00000000;
          block19_reg <= 32'h00000000;
          block20_reg <= 32'h00000000;
          block21_reg <= 32'h00000000;
          block22_reg <= 32'h00000000;
          block23_reg <= 32'h00000000;
          block24_reg <= 32'h00000000;
          block25_reg <= 32'h00000000;
          block26_reg <= 32'h00000000;
          block27_reg <= 32'h00000000;
          block28_reg <= 32'h00000000;
          block29_reg <= 32'h00000000;
          block30_reg <= 32'h00000000;
          block31_reg <= 32'h00000000;

          mixer_ctrl_reg <= CTRL_IDLE;
        end
      else
        begin
          if (block00_we)
            begin
              block00_reg <= muxed_entropy;
            end

          if (block01_we)
            begin
              block01_reg <= muxed_entropy;
            end

          if (block02_we)
            begin
              block02_reg <= muxed_entropy;
            end

          if (block03_we)
            begin
              block03_reg <= muxed_entropy;
            end

          if (block04_we)
            begin
              block04_reg <= muxed_entropy;
            end

          if (block05_we)
            begin
              block05_reg <= muxed_entropy;
            end

          if (block06_we)
            begin
              block06_reg <= muxed_entropy;
            end

          if (block07_we)
            begin
              block07_reg <= muxed_entropy;
            end

          if (block08_we)
            begin
              block08_reg <= muxed_entropy;
            end

          if (block09_we)
            begin
              block09_reg <= muxed_entropy;
            end

          if (block10_we)
            begin
              block10_reg <= muxed_entropy;
            end

          if (block11_we)
            begin
              block11_reg <= muxed_entropy;
            end

          if (block12_we)
            begin
              block12_reg <= muxed_entropy;
            end

          if (block13_we)
            begin
              block13_reg <= muxed_entropy;
            end

          if (block14_we)
            begin
              block14_reg <= muxed_entropy;
            end

          if (block15_we)
            begin
              block15_reg <= muxed_entropy;
            end

          if (block16_we)
            begin
              block16_reg <= muxed_entropy;
            end

          if (block17_we)
            begin
              block17_reg <= muxed_entropy;
            end

          if (block18_we)
            begin
              block18_reg <= muxed_entropy;
            end

          if (block19_we)
            begin
              block19_reg <= muxed_entropy;
            end

          if (block20_we)
            begin
              block20_reg <= muxed_entropy;
            end

          if (block21_we)
            begin
              block21_reg <= muxed_entropy;
            end

          if (block22_we)
            begin
              block22_reg <= muxed_entropy;
            end

          if (block23_we)
            begin
              block23_reg <= muxed_entropy;
            end

          if (block24_we)
            begin
              block24_reg <= muxed_entropy;
            end

          if (block25_we)
            begin
              block25_reg <= muxed_entropy;
            end

          if (block26_we)
            begin
              block26_reg <= muxed_entropy;
            end

          if (block27_we)
            begin
              block27_reg <= muxed_entropy;
            end

          if (block28_we)
            begin
              block28_reg <= muxed_entropy;
            end

          if (block29_we)
            begin
              block29_reg <= muxed_entropy;
            end

          if (block30_we)
            begin
              block30_reg <= muxed_entropy;
            end

          if (block31_we)
            begin
              block31_reg <= muxed_entropy;
            end

          if (mixer_ctrl_we)
            begin
              mixer_ctrl_reg <= mixer_ctrl_new;
            end
        end
    end // reg_update


  //----------------------------------------------------------------
  // mixer_ctrl_fsm
  //
  // Control FSM for the mixer.
  //----------------------------------------------------------------
  always @*
    begin : mixer_ctrl_fsm
      hash_init      = 0;
      hash_next      = 0;
      update_block   = 0;
      mixer_ctrl_new = CTRL_IDLE;
      mixer_ctrl_we  = 0;

      case (mixer_ctrl_reg)
        CTRL_IDLE:
          begin
            if (!enable)
              begin
                mixer_ctrl_new = CTRL_CANCEL;
                mixer_ctrl_we  = 1;
              end
            else if (more_seed)
              begin
                mixer_ctrl_new = CTRL_COLLECT;
                mixer_ctrl_we  = 1;
              end
          end

        CTRL_COLLECT:
          begin
            if ((!enable))
              begin
                mixer_ctrl_new = CTRL_CANCEL;
                mixer_ctrl_we  = 1;
              end
          end

        CTRL_CANCEL:
          begin
            mixer_ctrl_new  = CTRL_IDLE;
            mixer_ctrl_we   = 1;
          end

      endcase // case (cspng_ctrl_reg)
    end // mixer_ctrl_fsm

endmodule // trng_mixer

//======================================================================
// EOF trng_mixer.v
//======================================================================
