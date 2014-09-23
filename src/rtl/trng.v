 //======================================================================
//
// trng.v
// --------
// Top level wrapper for the True Random Number Generator.
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

module trng(
            // Clock and reset.
            input wire           clk,
            input wire           reset_n,

            input wire           avalanche_noise,

            input wire           cs,
            input wire           we,
            input wire  [15 : 0] address,
            input wire  [31 : 0] write_data,
            output wire [31 : 0] read_data,
            output wire          error,

            output wire  [7 : 0] debug,
            input wire           debug_update,

            output wire          security_error
           );


  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter ADDR_NAME0                  = 8'h00;
  parameter ADDR_NAME1                  = 8'h01;
  parameter ADDR_VERSION                = 8'h02;

  parameter ADDR_TRNG_CTRL              = 8'h10;
  parameter TRNG_CTRL_ENABLE_BIT        = 0;
  parameter TRNG_CTRL_ENT0_ENABLE_BIT   = 1;
  parameter TRNG_CTRL_ENT1_ENABLE_BIT   = 2;
  parameter TRNG_CTRL_ENT2_ENABLE_BIT   = 3;
  parameter TRNG_CTRL_SEED_BIT          = 8;

  parameter ADDR_TRNG_STATUS            = 8'h11;

  parameter ADDR_TRNG_RND_DATA          = 8'h20;
  parameter ADDR_TRNG_RND_DATA_VALID    = 8'h21;
  parameter TRNG_RND_VALID_BIT          = 0;

  parameter ADDR_CSPRNG_NUM_ROUNDS      = 8'h30;
  parameter ADDR_CSPRNG_NUM_BLOCKS_LOW  = 8'h31;
  parameter ADDR_CSPRNG_NUM_BLOCKS_HIGH = 8'h32;

  parameter ADDR_ENTROPY0_RAW           = 8'h40;
  parameter ADDR_ENTROPY0_STATS         = 8'h41;

  parameter ADDR_ENTROPY1_RAW           = 8'h50;
  parameter ADDR_ENTROPY1_STATS         = 8'h51;

  parameter ADDR_ENTROPY2_RAW           = 8'h60;
  parameter ADDR_ENTROPY2_STATS         = 8'h61;
  parameter ADDR_ENTROPY2_OP_A          = 8'h68;
  parameter ADDR_ENTROPY2_OP_B          = 8'h69;


  parameter TRNG_NAME0   = 32'h74726e67; // "trng"
  parameter TRNG_NAME1   = 32'h20202020; // "    "
  parameter TRNG_VERSION = 32'h302e3031; // "0.01"


  parameter CSPRNG_DEFAULT_NUM_ROUNDS = 5'h18;
  parameter CSPRNG_DEFAULT_NUM_BLOCKS = 64'h1000000000000000;


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [4 : 0] csprng_num_rounds_reg;
  reg [4 : 0] csprng_num_rounds_new;
  reg         csprng_num_rounds_we;

  reg [31 : 0] csprng_num_blocks_low_reg;
  reg [31 : 0] csprng_num_blocks_low_new;
  reg          csprng_num_blocks_low_we;

  reg [31 : 0] csprng_num_blocks_high_reg;
  reg [31 : 0] csprng_num_blocks_high_new;
  reg          csprng_num_blocks_high_we;

  reg          entropy0_enable_reg;
  reg          entropy0_enable_new;
  reg          entropy0_enable_we;

  reg          entropy1_enable_reg;
  reg          entropy1_enable_new;
  reg          entropy1_enable_we;

  reg          entropy2_enable_reg;
  reg          entropy2_enable_new;
  reg          entropy2_enable_we;

  reg [31 : 0] entropy2_op_a_reg;
  reg [31 : 0] entropy2_op_a_new;
  reg          entropy2_op_a_we;

  reg [31 : 0] entropy2_op_b_reg;
  reg [31 : 0] entropy2_op_b_new;
  reg          entropy2_op_b_we;

  reg          enable_reg;
  reg          enable_new;
  reg          enable_we;

  reg          csprng_seed_reg;
  reg          csprng_seed_new;

  reg          csprng_rnd_ack_reg;
  reg          csprng_rnd_ack_new;



  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  wire           entropy0_enable;
  wire [31 : 0]  entropy0_raw;
  wire [31 : 0]  entropy0_stats;
  wire           entropy0_enabled;
  wire           entropy0_syn;
  wire [31 : 0]  entropy0_data;
  wire           entropy0_ack;

  wire           entropy1_enable;
  wire [31 : 0]  entropy1_raw;
  wire [31 : 0]  entropy1_stats;
  wire           entropy1_enabled;
  wire           entropy1_syn;
  wire [31 : 0]  entropy1_data;
  wire           entropy1_ack;

  wire           entropy2_enable;
  wire [31 : 0]  entropy2_raw;
  wire [31 : 0]  entropy2_stats;
  wire           entropy2_enabled;
  wire           entropy2_syn;
  wire [31 : 0]  entropy2_data;
  wire           entropy2_ack;
  wire [7 : 0]   entropy2_debug;

  wire           mixer_enable;
  wire [511 : 0] mixer_seed_data;
  wire           mixer_seed_syn;

  wire           csprng_enable;
  wire           csprng_debug_mode;
  wire [4 : 0]   csprng_num_rounds;
  wire [63 : 0]  csprng_num_blocks;
  wire           csprng_seed;
  wire           csprng_more_seed;
  wire           csprng_seed_ack;
  wire           csprng_ready;
  wire           csprng_error;
  wire [31 : 0]  csprng_rnd_data;
  wire           csprng_rnd_syn;

  reg [31 : 0]   tmp_read_data;
  reg            tmp_error;


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign read_data      = tmp_read_data;
  assign error          = tmp_error;
  assign security_error = 0;
  assign debug          = entropy2_debug;

  assign csprng_num_blocks = {csprng_num_blocks_high_reg,
                              csprng_num_blocks_low_reg};

  assign entropy0_enable = entropy0_enable_reg;
  assign entropy1_enable = entropy1_enable_reg;
  assign entropy2_enable = entropy2_enable_reg;

  assign mixer_enable  = enable_reg;

  assign csprng_enable     = enable_reg;
  assign csprng_seed       = csprng_seed_reg;
  assign csprng_debug_mode = 0;

  // Patches to get our first version to work.
  assign entropy0_enabled = 0;
  assign entropy0_raw     = 32'h00000000;
  assign entropy0_stats   = 32'h00000000;
  assign entropy0_syn     = 0;
  assign entropy0_data    = 32'h00000000;

  assign entropy1_enabled = 1;

  assign entropy2_enabled = 1;
  assign entropy2_stats   = 32'h00000000;


  //----------------------------------------------------------------
  // core instantiations.
  //----------------------------------------------------------------
  trng_mixer mixer(
                   .clk(clk),
                   .reset_n(reset_n),

                   .enable(mixer_enable),
                   .more_seed(csprng_more_seed),

                   .entropy0_enabled(entropy0_enabled),
                   .entropy0_syn(entropy0_syn),
                   .entropy0_data(entropy0_data),
                   .entropy0_ack(entropy0_ack),

                   .entropy1_enabled(entropy1_enabled),
                   .entropy1_syn(entropy1_syn),
                   .entropy1_data(entropy1_data),
                   .entropy1_ack(entropy1_ack),

                   .entropy2_enabled(entropy2_enabled),
                   .entropy2_syn(entropy2_syn),
                   .entropy2_data(entropy2_data),
                   .entropy2_ack(entropy2_ack),

                   .seed_data(mixer_seed_data),
                   .seed_syn(mixer_seed_syn),
                   .seed_ack(csprng_seed_ack)
                  );

  trng_csprng csprng(
                     .clk(clk),
                     .reset_n(reset_n),

                     .enable(csprng_enable),
                     .debug_mode(csprng_debug_mode),
                     .num_rounds(csprng_num_rounds_reg),
                     .num_blocks(csprng_num_blocks),
                     .seed(csprng_seed),
                     .more_seed(csprng_more_seed),
                     .ready(csprng_ready),
                     .error(csprng_error),

                     .seed_data(mixer_seed_data),
                     .seed_syn(mixer_seed_syn),
                     .seed_ack(csprng_seed_ack),

                     .rnd_data(csprng_rnd_data),
                     .rnd_syn(csprng_rnd_syn),
                     .rnd_ack(csprng_rnd_ack_reg)
                    );

//  pseudo_entropy entropy0(
//                          .clk(clk),
//                          .reset_n(reset_n),
//
//                          .enable(entropy0_enable),
//
//                          .raw_entropy(entropy0_raw),
//                          .stats(entropy0_stats),
//
//                          .enabled(entropy0_enabled),
//                          .entropy_syn(entropy0_syn),
//                          .entropy_data(entropy0_data),
//                          .entropy_ack(entropy0_ack)
//                         );

  avalanche_entropy_core entropy1(
                                 .clk(clk),
                                 .reset_n(reset_n),

                                 .noise(avalanche_noise),
                                 .sampled_noise(),
                                 .entropy(),

                                 .entropy_syn(entropy1_syn),
                                 .entropy_data(entropy1_data),
                                 .entropy_ack(entropy1_ack),

                                 .led(),
                                 .debug_data(entropy1_raw),
                                 .debug_clk(),

                                 .delta_data(entropy1_stats),
                                 .delta_clk()
                                );

  rosc_entropy_core entropy2(
                             .clk(clk),
                             .reset_n(reset_n),

                             .enable(entropy2_enable),

                             .opa(entropy2_op_a_reg),
                             .opb(entropy2_op_b_reg),

                             .entropy(entropy2_raw),

                             .rnd_data(entropy2_data),
                             .rnd_valid(entropy2_syn),
                             .rnd_ack(entropy2_ack),

                             .debug(entropy2_debug),
                             .debug_update(debug_update)
                            );


  //----------------------------------------------------------------
  // reg_update
  //
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active low reset. All registers have write enable.
  //----------------------------------------------------------------
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        begin
          entropy0_enable_reg        <= 1;
          entropy1_enable_reg        <= 1;
          entropy2_enable_reg        <= 1;
          entropy2_op_a_reg          <= 32'h01010101;
          entropy2_op_a_reg          <= 32'h10101010;
          enable_reg                 <= 1;
          csprng_rnd_ack_reg         <= 0;
          csprng_seed_reg            <= 0;
          csprng_num_rounds_reg      <= CSPRNG_DEFAULT_NUM_ROUNDS;
          csprng_num_blocks_low_reg  <= CSPRNG_DEFAULT_NUM_BLOCKS[31 : 0];
          csprng_num_blocks_high_reg <= CSPRNG_DEFAULT_NUM_BLOCKS[63 : 32];
        end
      else
        begin
          csprng_rnd_ack_reg <= csprng_rnd_ack_new;
          csprng_seed_reg    <= csprng_seed_new;

          if (entropy0_enable_we)
            begin
              entropy0_enable_reg <= entropy0_enable_new;
            end

          if (entropy1_enable_we)
            begin
              entropy1_enable_reg <= entropy1_enable_new;
            end

          if (entropy2_enable_we)
            begin
              entropy2_enable_reg <= entropy2_enable_new;
            end

          if (entropy2_op_a_we)
            begin
              entropy2_op_a_reg <= entropy2_op_a_new;
            end

          if (entropy2_op_b_we)
            begin
              entropy2_op_b_reg <= entropy2_op_b_new;
            end

          if (enable_we)
            begin
              enable_reg <= enable_new;
            end

          if (csprng_num_rounds_we)
            begin
              csprng_num_rounds_reg <= csprng_num_rounds_new;
            end

          if (csprng_num_blocks_low_we)
            begin
              csprng_num_blocks_low_reg <= csprng_num_blocks_low_new;
            end

          if (csprng_num_blocks_high_we)
            begin
              csprng_num_blocks_high_reg <= csprng_num_blocks_high_new;
            end
        end
    end // reg_update


  //----------------------------------------------------------------
  // api_logic
  //
  // Implementation of the api logic. If cs is enabled will either
  // try to write to or read from the internal registers.
  //----------------------------------------------------------------
  always @*
    begin : api_logic
      entropy0_enable_new        = 0;
      entropy0_enable_we         = 0;
      entropy1_enable_new        = 0;
      entropy1_enable_we         = 0;
      entropy2_enable_new        = 0;
      entropy2_enable_we         = 0;
      entropy2_op_a_new          = 32'h00000000;
      entropy2_op_a_we           = 0;
      entropy2_op_b_new          = 32'h00000000;
      entropy2_op_b_we           = 0;
      enable_new                 = 0;
      enable_we                  = 0;
      csprng_seed_new            = 0;
      csprng_rnd_ack_new         = 0;
      csprng_seed_new            = 0;
      csprng_num_rounds_new      = 5'h00;
      csprng_num_rounds_we       = 0;
      csprng_num_blocks_low_new  = 32'h00000000;
      csprng_num_blocks_low_we   = 0;
      csprng_num_blocks_high_new = 32'h00000000;
      csprng_num_blocks_high_we  = 0;
      tmp_read_data              = 32'h00000000;
      tmp_error                  = 0;

      if (cs)
        begin
          if (we)
            begin
              // Write operations.
              case (address)
                // Write operations.
                ADDR_TRNG_CTRL:
                  begin
                    enable_new          = write_data[TRNG_CTRL_ENABLE_BIT];
                    enable_we           = 1;
                    entropy0_enable_new = write_data[TRNG_CTRL_ENT0_ENABLE_BIT];
                    entropy0_enable_we  = 1;
                    entropy1_enable_new = write_data[TRNG_CTRL_ENT1_ENABLE_BIT];
                    entropy1_enable_we  = 1;
                    entropy2_enable_new = write_data[TRNG_CTRL_ENT2_ENABLE_BIT];
                    entropy2_enable_we  = 1;
                    csprng_seed_new     = write_data[TRNG_CTRL_SEED_BIT];
                  end

                ADDR_CSPRNG_NUM_ROUNDS:
                  begin
                    csprng_num_rounds_new = write_data[4 : 0];
                    csprng_num_rounds_we  = 1;
                  end

                ADDR_CSPRNG_NUM_BLOCKS_LOW:
                  begin
                    csprng_num_blocks_low_new = write_data;
                    csprng_num_blocks_low_we  = 1;
                  end

                ADDR_CSPRNG_NUM_BLOCKS_HIGH:
                  begin
                    csprng_num_blocks_high_new = write_data;
                    csprng_num_blocks_high_we  = 1;
                  end

                ADDR_ENTROPY2_OP_A:
                  begin
                    entropy2_op_a_new = write_data;
                    entropy2_op_a_we  = 1;
                  end

                ADDR_ENTROPY2_OP_B:
                  begin
                    entropy2_op_b_new = write_data;
                    entropy2_op_b_we  = 1;
                  end

                default:
                  begin
                    tmp_error = 1;
                  end
              endcase // case (address)
            end // if (we)

          else
            begin
              // Read operations.
              case (address)
                // Read operations.
                ADDR_NAME0:
                  begin
                    tmp_read_data = TRNG_NAME0;
                  end

                ADDR_NAME1:
                  begin
                    tmp_read_data = TRNG_NAME1;
                  end

                ADDR_VERSION:
                  begin
                    tmp_read_data = TRNG_VERSION;
                  end

                ADDR_TRNG_CTRL:
                  begin
                    tmp_read_data[TRNG_CTRL_ENABLE_BIT]      = enable_reg;
                    tmp_read_data[TRNG_CTRL_ENT0_ENABLE_BIT] = entropy0_enable_reg;
                    tmp_read_data[TRNG_CTRL_ENT1_ENABLE_BIT] = entropy1_enable_reg;
                    tmp_read_data[TRNG_CTRL_ENT2_ENABLE_BIT] = entropy2_enable_reg;
                    tmp_read_data[TRNG_CTRL_SEED_BIT]        = csprng_seed_reg;
                  end

                ADDR_TRNG_STATUS:
                  begin

                  end

                ADDR_TRNG_RND_DATA:
                  begin
                    csprng_rnd_ack_new = 1;
                    tmp_read_data      = csprng_rnd_data;
                  end

                ADDR_TRNG_RND_DATA_VALID:
                  begin
                    tmp_read_data[TRNG_RND_VALID_BIT] = csprng_rnd_syn;
                  end

                ADDR_CSPRNG_NUM_ROUNDS:
                  begin
                    tmp_read_data[4 : 0] = csprng_num_rounds_reg;
                  end

                ADDR_CSPRNG_NUM_BLOCKS_LOW:
                  begin
                    tmp_read_data = csprng_num_blocks_low_reg;
                  end

                ADDR_CSPRNG_NUM_BLOCKS_HIGH:
                  begin
                    tmp_read_data = csprng_num_blocks_high_reg;
                  end

                ADDR_ENTROPY0_RAW:
                  begin
                    tmp_read_data = entropy0_raw;
                  end

                ADDR_ENTROPY0_STATS:
                  begin
                    tmp_read_data = entropy0_stats;
                  end

                ADDR_ENTROPY1_RAW:
                  begin
                    tmp_read_data = entropy1_raw;
                  end

                ADDR_ENTROPY1_STATS:
                  begin
                    tmp_read_data = entropy1_stats;
                  end

                ADDR_ENTROPY2_RAW:
                  begin
                    tmp_read_data = entropy2_raw;
                  end

                ADDR_ENTROPY2_STATS:
                  begin
                    tmp_read_data = entropy2_stats;
                  end

                default:
                  begin
                    tmp_error = 1;
                  end
              endcase // case (address)
            end
        end
    end // addr_decoder
endmodule // trng

//======================================================================
// EOF trng.v
//======================================================================
