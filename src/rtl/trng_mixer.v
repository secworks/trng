//======================================================================
//
// trng_mixer.v
// ----------------------
// Entropy source mixer and seed generator for the
// True Random Number Generator.
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

                  // Control, config and status.
                  input wire [7 : 0]   num_blocks,
                  input wire           init,
                  output               error,

                  // Seed input ports.
                  input wire           entropy0_syn,
                  input [31 : 0]       entropy0_data,
                  output wire          entropy0_ack,

                  input wire           entropy1_syn,
                  input [31 : 0]       entropy1_data,
                  output wire          entropy1_ack,

                  input wire           entropy2_syn,
                  input [31 : 0]       entropy2_data,
                  output wire          entropy2_ack,

                  // RNG output
                  output wire           seed_syn,
                  output wire [511 : 0] seed_data,
                  input wire            seed_ack
                 );


  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter SEED_BUFFER_SIZE = 2;


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [511 : 0]  seed_buffer_mem [0 : (SEED_BUFFER_SIZE - 1)];
  reg [511 : 0]  seed_buffer_mem_data;
  wire [511 : 0] seed_buffer_mem_new;
  reg            seed_buffer_mem_we;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign seed_data = seed_buffer_mem_data;


  //----------------------------------------------------------------
  // core instantiation.
  //----------------------------------------------------------------
  sha512_core sha512(
                     .clk(clk),
                     .reset_n(reset_n),

                     .init(sha512_init),
                     .next(sha512_next),

                     .block(sha512_block),

                     .ready(sha512_ready),

                     .digest(seed_buffer_mem_new),
                     .digest_valid(sha512_digest_valid)
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

        end
      else
        begin

        end
    end // reg_update

endmodule // trng_mixer

//======================================================================
// EOF trng_mixer.v
//======================================================================
