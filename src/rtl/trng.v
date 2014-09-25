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
            input wire  [11 : 0] address,
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
  parameter TRNG_PREFIX                 = 4'h00;
  parameter ENTROPY0_PREFIX             = 4'h04;
  parameter ENTROPY1_PREFIX             = 4'h05;
  parameter ENTROPY2_PREFIX             = 4'h06;
  parameter MIXER_PREFIX                = 4'h0a;
  parameter CSPRNG_PREFIX               = 4'h0b;

  parameter ADDR_NAME0                  = 8'h00;
  parameter ADDR_NAME1                  = 8'h01;
  parameter ADDR_VERSION                = 8'h02;

  parameter ADDR_TRNG_CTRL              = 8'h10;
  parameter TRNG_CTRL_DISCARD_BIT       = 0;
  parameter TRNG_CTRL_SEED_BIT          = 1;
  parameter TRNG_CTRL_TEST_MODE_BIT     = 2;

  parameter ADDR_TRNG_STATUS            = 8'h11;

  parameter TRNG_NAME0   = 32'h74726e67; // "trng"
  parameter TRNG_NAME1   = 32'h20202020; // "    "
  parameter TRNG_VERSION = 32'h302e3031; // "0.01"


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg discard_reg;
  reg discard_new;

  reg test_mode_reg;
  reg test_mode_new;
  reg test_mode_we;

  reg seed_reg;
  reg seed_new;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  wire           mixer_discard;
  wire           mixer_test_mode;
  wire           mixer_more_seed;
  wire [511 : 0] mixer_seed_data;
  wire           mixer_seed_syn;
  wire           mixer_seed_ack;
  wire           mixer_api_cs;
  wire           mixer_api_we;
  wire  [7 : 0]  mixer_api_address;
  wire  [31 : 0] mixer_api_write_data;
  wire [31 : 0]  mixer_api_read_data;
  wire           mixer_api_error;

  wire           csprng_discard;
  wire           csprng_test_mode;
  wire           csprng_seed;
  wire           csprng_more_seed;
  wire           csprng_seed_ack;
  wire           csprng_api_cs;
  wire           csprng_api_we;
  wire  [7 : 0]  csprng_api_address;
  wire  [31 : 0] csprng_api_write_data;
  wire [31 : 0]  csprng_api_read_data;
  wire           csprng_api_error;
  wire           csprng_security_error;

  wire           entropy0_api_cs;
  wire           entropy0_api_we;
  wire  [7 : 0]  entropy0_api_address;
  wire  [31 : 0] entropy0_api_write_data;
  wire [31 : 0]  entropy0_api_read_data;
  wire           entropy0_api_error;
  wire           entropy0_entropy_enabled;
  wire [31 : 9]  entropy0_entropy_data;
  wire           entropy0_entropy_syn;
  wire           entropy0_entropy_ack;
  wire           entropy0_test_mode;
  wire [7 : 0]   entropy0_debug;
  wire           entropy0_debug_update;
  wire           entropy0_security_error;

  wire           entropy1_noise;
  wire           entropy1_api_cs;
  wire           entropy1_api_we;
  wire  [7 : 0]  entropy1_api_address;
  wire  [31 : 0] entropy1_api_write_data;
  wire [31 : 0]  entropy1_api_read_data;
  wire           entropy1_api_error;
  wire           entropy1_entropy_enabled;
  wire [31 : 9]  entropy1_entropy_data;
  wire           entropy1_entropy_syn;
  wire           entropy1_entropy_ack;
  wire           entropy1_test_mode;
  wire [7 : 0]   entropy1_debug;
  wire           entropy1_debug_update;
  wire           entropy1_security_error;

  wire           entropy2_api_cs;
  wire           entropy2_api_we;
  wire  [7 : 0]  entropy2_api_address;
  wire  [31 : 0] entropy2_api_write_data;
  wire [31 : 0]  entropy2_api_read_data;
  wire           entropy2_api_error;
  wire           entropy2_entropy_enabled;
  wire [31 : 9]  entropy2_entropy_data;
  wire           entropy2_entropy_syn;
  wire           entropy2_entropy_ack;
  wire           entropy2_test_mode;
  wire [7 : 0]   entropy2_debug;
  wire           entropy2_debug_update;
  wire           entropy2_security_error;

  reg [31 : 0]   tmp_read_data;
  reg            tmp_error;


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign read_data      = tmp_read_data;
  assign error          = tmp_error;
  assign security_error = entropy0_security_error | entropy1_security_error |
                          entropy2_security_error;
  assign debug          = entropy2_debug;

  assign csprng_seed       = seed_reg;

  assign mixer_discard  = discard_reg;
  assign csprng_discard = discard_reg;

  assign mixer_test_mode    = test_mode_reg;
  assign csprng_test_mode   = test_mode_reg;
  assign entropy0_test_mode = test_mode_reg;
  assign entropy1_test_mode = test_mode_reg;
  assign entropy2_test_mode = test_mode_reg;

  assign entropy1_noise = avalanche_noise;

  // Patches to get our first version to work.
  assign entropy0_enabled = 0;
  assign entropy0_raw     = 32'h00000000;
  assign entropy0_stats   = 32'h00000000;
  assign entropy0_syn     = 0;
  assign entropy0_data    = 32'h00000000;


  //----------------------------------------------------------------
  // core instantiations.
  //----------------------------------------------------------------
  trng_mixer mixer(
                   .clk(clk),
                   .reset_n(reset_n),

                   .cs(mixer_api_cs),
                   .we(mixer_api_we),
                   .address(mixer_api_address),
                   .write_data(mixer_api_write_data),
                   .read_data(mixer_api_read_data),
                   .error(mixer_api_error),

                   .discard(mixer_discard),
                   .test_mode(mixer_test_mode),

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

                     .cs(csprng_api_cs),
                     .we(csprng_api_we),
                     .address(csprng_api_address),
                     .write_data(csprng_api_write_data),
                     .read_data(csprng_api_read_data),
                     .error(csprng_api_error),

                     .discard(csprng_discard),
                     .test_mode(csprng_test_mode),

                     .more_seed(csprng_more_seed),

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

  avalanche_entropy entropy1(
                             .clk(clk),
                             .reset_n(reset_n),

                             .noise(entropy1_noise),

                             .cs(entropy1_api_cs),
                             .we(entropy1_api_we),
                             .address(entropy1_api_address),
                             .write_data(entropy1_api_write_data),
                             .read_data(entropy1_api_read_data),
                             .error(entropy1_api_error),

                             .entropy_enabled(entropy1_syn),
                             .entropy_syn(entropy1_syn),
                             .entropy_data(entropy1_data),
                             .entropy_ack(entropy1_ack),

                             .debug(entropy1_debug),
                             .debug_update(entropy1_debug_update),

                             .security_error(entropy1_security_error)
                            );

  rosc_entropy entropy2(
                        .clk(clk),
                        .reset_n(reset_n),

                        .cs(entropy2_api_cs),
                        .we(entropy2_api_we),
                        .address(entropy2_api_address),
                        .write_data(entropy2_api_write_data),
                        .read_data(entropy2_api_read_data),
                        .error(entropy2_api_error),

                        .entropy_enabled(entropy2_enabled),
                        .entropy_data(entropy2_data),
                        .entropy_valid(entropy2_syn),
                        .entropy_ack(entropy2_ack),

                        .debug(entropy2_debug),
                        .debug_update(entropy2_debug_update),

                        .security_error(entropy2_security_error)
                       );


  //----------------------------------------------------------------
  // reg_update
  //
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active low reset.
  //----------------------------------------------------------------
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        begin
          discard_reg <= 0;
          seed_reg    <= 0;
          test_mode_reg <= 0;
        end
      else
        begin
          discard_reg <= discard_new;
          seed_reg    <= seed_new0;

          if (test_mode_we)
            begin
              test_mode_reg <= test_mode_new;
            end
        end
    end // reg_update


  //----------------------------------------------------------------
  // api_mux
  //
  // This is a simple decoder that looks at the top 4 bits of
  // the given api address and selects which of the sub modules
  // or the top level mux that gets to handle any API
  // operations.
  //----------------------------------------------------------------
  always @*
    begin : api_mux
      trng_api_cs             = 0;
      trng_api_we             = 0;
      trng_api_address        = 8'h00;
      trng_api_write_data     = 32'h00000000;
      trng_read_data          = 32'h00000000;
      trng_error              = 0;

      entropy1_api_cs         = 0;
      entropy1_api_we         = 0;
      entropy1_api_address    = 8'h00;
      entropy1_api_write_data = 32'h00000000;
      entropy1_read_data      = 32'h00000000;
      entropy1_error          = 0;

      entropy2_api_cs         = 0;
      entropy2_api_we         = 0;
      entropy2_api_address    = 8'h00;
      entropy2_api_write_data = 32'h00000000;
      entropy2_read_data      = 32'h00000000;
      entropy2_error          = 0;

      mixer_api_cs            = 0;
      mixer_api_we            = 0;
      mixer_api_address       = 8'h00;
      mixer_api_write_data    = 32'h00000000;
      mixer_read_data         = 32'h00000000;
      mixer_error             = 0;

      csprng_api_cs           = 0;
      csprng_api_we           = 0;
      csprng_api_address      = 8'h00;
      csprng_api_write_data   = 32'h00000000;
      csprng_read_data        = 32'h00000000;
      csprng_error            = 0;

      tmp_read_data           = 32'h00000000;
      tmp_error               = 0;

      case (address[11 : 8])
        TRNG_PREFIX:
          begin
            trng_api_cs         = cs;
            trng_api_we         = we;
            trng_api_address    = address[7 : 0];
            trng_api_write_data = write_data;
            tmp_read_data       = trng_read_data;
            tmp_error           = trng_error;
          end

        ENTROPY0_PREFIX:
          begin
            entropy0_api_cs         = cs;
            entropy0_api_we         = we;
            entropy0_api_address    = address[7 : 0];
            entropy0_api_write_data = write_data;
            tmp_read_data           = entropy0_read_data;
            tmp_error               = entropy0_error;
          end

        ENTROPY1_PREFIX:
          begin
            entropy1_api_cs         = cs;
            entropy1_api_we         = we;
            entropy1_api_address    = address[7 : 0];
            entropy1_api_write_data = write_data;
            tmp_read_data           = entropy1_read_data;
            tmp_error               = entropy1_error;
          end

        ENTROPY2_PREFIX:
          begin
            entropy2_api_cs         = cs;
            entropy2_api_we         = we;
            entropy2_api_address    = address[7 : 0];
            entropy2_api_write_data = write_data;
            tmp_read_data           = entropy2_read_data;
            tmp_error               = entropy2_error;
          end

        MIXER_PREFIX:
          begin
            entropy0_api_cs         = cs;
            entropy0_api_we         = we;
            entropy0_api_address    = address[7 : 0];
            entropy0_api_write_data = write_data;
            tmp_read_data           = entropy0_read_data;
            tmp_error               = entropy0_error;
          end

        CSPRNG_PREFIX:
          begin
            entropy0_api_cs         = cs;
            entropy0_api_we         = we;
            entropy0_api_address    = address[7 : 0];
            entropy0_api_write_data = write_data;
            tmp_read_data           = entropy0_read_data;
            tmp_error               = entropy0_error;
          end

        default:
          begin

          end
      endcase // case (address[11 : 8])
    end // api_mux


  //----------------------------------------------------------------
  // trng_api_logic
  //
  // Implementation of the top level api logic.
  //----------------------------------------------------------------
  always @*
    begin : trng_api_logic
      discard_new    = 0;
      seed_new       = 0;
      test_mode_new  = 0;
      test_mode_we   = 0;
      trng_read_data = 32'h00000000;
      trng_error     = 0;

      if (cs)
        begin
          if (we)
            begin
              // Write operations.
              case (address)
                // Write operations.
                ADDR_TRNG_CTRL:
                  begin
                    discard_new   = write_data[TRNG_CTRL_DISCARD_BIT];
                    seed_new      = write_data[TRNG_CTRL_SEED_BIT];
                    test_mode_new = write_data[TRNG_CTRL_TEST_MODE_BIT];
                    test_mode_we  = 1;
                  end

                default:
                  begin
                    trng_error = 1;
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
                    trng_read_data = TRNG_NAME0;
                  end

                ADDR_NAME1:
                  begin
                    trng_read_data = TRNG_NAME1;
                  end

                ADDR_VERSION:
                  begin
                    trng_read_data = TRNG_VERSION;
                  end

                ADDR_TRNG_CTRL:
                  begin
                  end

                ADDR_TRNG_STATUS:
                  begin

                  end

                default:
                  begin
                    trng_error = 1;
                  end
              endcase // case (address)
            end
        end
    end // trng_api_logic
endmodule // trng

//======================================================================
// EOF trng.v
//======================================================================
