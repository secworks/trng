//======================================================================
//
// trng_csprng.v
// -------------
// CSPRNG for the TRNG.
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

module trng_csprng(
                   // Clock and reset.
                   input wire           clk,
                   input wire           reset_n,

                   // Control, config and status.
                   input                debug_mode,
                   input wire [5 : 0]   num_rounds,
                   input wire [63 : 0]  num_blocks;
                   input wire           seed,
                   input wire           generate,
                   output               error,

                   // Seed input
                   input wire           seed_syn,
                   input [511 : 0]      seed_data,
                   output wire          seed_ack,

                   // RNG output
                   output wire          rng_syn,
                   output wire [31 : 0] rng_data,
                   input wire           rng_ack
                  );


  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter ADDR_NAME0         = 8'h00;
  parameter ADDR_NAME1         = 8'h01;
  parameter ADDR_VERSION       = 8'h02;
  parameter ADDR_ROUNDS        = 8'h11;

  parameter CORE_NAME0         = 32'h73686132; // "sha2"
  parameter CORE_NAME1         = 32'h2d323536; // "-512"
  parameter CORE_VERSION       = 32'h302e3830; // "0.80"

  parameter CHACHA_KEYLEN256      = 1'b1; // 256 bit key.
  parameter CHACHA_DEFAULT_ROUNDS = 5'b18; // 24 rounds.
  parameter MAX_BLOCKS            = 64'h1000000000000000;

  parameter CTRL_IDLE      = 3'h0;
  parameter CTRL_SEED0     = 3'h1;
  parameter CTRL_SEED0_ACK = 3'h2;
  parameter CTRL_SEED1     = 3'h3;
  parameter CTRL_SEED1_ACK = 3'h4;
  parameter CTRL_GENERATE  = 3'h5;


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [255 : 0] key_reg;
  reg           key_we;

  reg [63 : 0]  iv_reg;
  reg           iv_we;

  reg [511 : 0] block_reg;
  reg           block_we;

  reg [63 : 0]  block_ctr_reg;
  reg [63 : 0]  block_ctr_new;
  reg           block_ctr_inc;
  reg           block_ctr_set;
  reg           block_ctr_we;

  reg [2 : 0]   csprng_ctrl_reg;
  reg [2 : 0]   csprng_ctrl_new;
  reg           csprng_ctrl_we;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg [511 : 0] chacha_data_out;
  reg           chacha_data_out_valid;

  reg [31 : 0] tmp_read_data;
  reg          tmp_error;

  reg          tmp_seed_ack;


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign read_data = tmp_read_data;
  assign error     = tmp_error;

  assign seed_ack  = tmp_seed_ack;


  //----------------------------------------------------------------
  // core instantiation.
  //----------------------------------------------------------------
  chacha_core chacha(
                     .clk(clk),
                     .reset_n(reset_n),

                     .init(chacha_init),
                     .next(chacha_next),

                     .key(key_reg),
                     .keylen(CHACHA_KEYLEN256),
                     .iv(iv_reg),
                     .rounds(rounds_reg),

                     .data_in(block_reg),

                     .ready(chacha_ready),

                     .data_out(chacha_data_out),
                     .data_out_valid(chacha_data_out_valid)
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
          key_reg         <= {8{32'h00000000}};
          iv_reg          <= {2{32'h00000000}};
          block_reg       <= {16{32'h00000000}};
          block_ctr_reg   <= {2{32'h00000000}};
          csprng_ctrl_reg <= CTRL_IDLE;
        end
      else
        begin
          if (key_we)
            begin
              key_reg <= seed_data[255 : 0];
            end

          if (iv_we)
            begin
              key_reg <= seed_data[319 : 256];
            end

          if (block_we)
            begin
              block_reg <= seed_data;
            end

          if (block_ctr_we)
            begin
              block_ctr_reg <= block_ctr_new;
            end

          if (csprng_ctrl_we)
            begin
              csprng_ctrl_reg <= csprng_ctrl_new;
            end
        end
    end // reg_update


  //----------------------------------------------------------------
  // csprng_ctrl_fsm
  //
  // Control FSM for the CSPRNG.
  //----------------------------------------------------------------
  always @*
    begin : csprng_ctrl_fsm
      cipher_key_we   = 0;
      cipher_iv_we    = 0;
      cipher_ctr_we   = 0;
      cipher_block_we = 0;

      tmp_seed_ack = 0;

      csprng_ctrl_new    = CTRL_IDLE;
      csprng_ctrl_we     = 0;


      case (cspng_ctrl_reg)
        CTRL_IDLE:
          begin
            if (seed)
              begin
                csprng_ctrl_new = CTRL_SEED0;
                csprng_ctrl_we    = 1;
              end
          end

        CTRL_SEED0:
          begin
            if (seed_syn)
              begin
                cipher_block_we = 1;
                csprng_ctrl_new = CTRL_SEED0_ACK;
                csprng_ctrl_we  = 1;
              end
          end

        CTRL_SEED0_ACK:
          begin
            tmp_seed_ack    = 1;
            csprng_ctrl_new = CTRL_SEED1;
            csprng_ctrl_we  = 1;
          end

        CTRL_SEED1:
          begin
            if (seed_syn)
              begin
                cipher_key_we   = 1;
                cipher_iv_we    = 1;
                cipher_ctr_we   = 1;
                csprng_ctrl_new = CTRL_SEED1_ACK;
                csprng_ctrl_we  = 1;
              end
          end

        CTRL_SEED1_ACK:
          begin
            tmp_seed_ack    = 1;
            csprng_ctrl_new = CTRL_GENERATE;
            csprng_ctrl_we  = 1;
          end

        CTRL_GENERATE:
          begin
            csprng_ctrl_new = CTRL_GENERATE;
            csprng_ctrl_we  = 1;
          end

      endcase // case (cspng_ctrl_reg)
    end // csprng_ctrl_fsm

endmodule // trng_csprng

//======================================================================
// EOF trng_csprng.
//======================================================================
