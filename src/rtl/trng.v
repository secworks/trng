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
            
            // Control.
            input wire           cs,
            input wire           we,
              
            // Data ports.
            input wire  [7 : 0]  address,
            input wire  [31 : 0] write_data,
            output wire [31 : 0] read_data,
            output wire          error,

            output wire          security_error
           );

  
  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter ADDR_NAME0         = 8'h00;
  parameter ADDR_NAME1         = 8'h01;
  parameter ADDR_VERSION       = 8'h02;

  parameter CSPRNG_NUM_ROUNDS  = 8'h80;
  
  parameter TRNG_NAME0         = 32'h74726e67; // "trng"
  parameter TRNG_NAME1         = 32'h20202020; // "    "
  parameter TRNG_VERSION       = 32'h302e3031; // "0.01"

  parameter CSPRNG_DEFAULT_NUM_ROUNDS = 6'h18;
  
  
  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [5 : 0] csprng_num_rounds_reg;
  reg [5 : 0] csprng_num_rounds_new;
  reg         csprng_num_rounds_we;

  
  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------

  reg            mixer_enable;

  wire           entropy0_enabled;
  wire           entropy0_syn;
  wire [31 : 0]  entropy0_data;
  wire           entropy0_ack;

  wire           entropy1_enabled;
  wire           entropy1_syn;
  wire [31 : 0]  entropy1_data;
  wire           entropy1_ack;

  wire           entropy2_enabled;
  wire           entropy2_syn;
  wire [31 : 0]  entropy2_data;
  wire           entropy2_ack;

  wire [511 : 0] mixer_seed_data;
  wire           mixer_seed_syn;
  wire           mixer_seed_ack;
  
  wire           csprng_enable;
  wire           csprng_debug_mode;
  wire           csprng_num_rounds;
  wire           csprng_num_blocks;
  wire           csprng_seed;
  wire           csprng_more_seed;
  wire           csprng_ready;
  wire           csprng_error;

  wire           csprng_rnperror;
  wire           csprng_error;
  
  wire           ctrl_rng_ack;
  
  reg [31 : 0] tmp_read_data;
  reg          tmp_error;
  
  
  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign read_data = tmp_read_data;
  assign error     = tmp_error;
  
             
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
                   .seed_ack(mixer_seed_ack)
                  );
  
  trng_csprng csprng(
                     .clk(clk),
                     .reset_n(reset_n),

                     .enable(csprng_enable),
                     .debug_mode(csprng_debug_mode),
                     .num_rounds(csprng_num_rounds),
                     .num_rounds(csprng_num_blocks),
                     .seed(csprng_seed),
                     .more_seed(csprng_more_seed),
                     .ready(csprng_ready),
                     .error(csprng_error),
                     
                     .seed_data(mixer_seed_data),
                     .seed_syn(mixer_seed_syn),
                     .seed_ack(csprng_seed_ack),

                     .rnd_data(csprng_rng_data),
                     .rnd_syn(csprng_rng_syn),
                     .rnd_ack(ctrl_rng_ack)
                    );

  
  //----------------------------------------------------------------
  // reg_update
  //
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with synchronous
  // active low reset. All registers have write enable.
  //----------------------------------------------------------------
  always @ (posedge clk)
    begin
      if (!reset_n)
        begin
          csprng_num_rounds_reg <= CSPRNG_DEFAULT_NUM_ROUNDS;
        end
      else
        begin
          if (csprng_num_rounds_we)
            begin
              csprng_num_rounds_reg <= csprng_num_rounds_new;
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
      csprng_num_rounds_new = 6'h00;
      csprng_num_rounds_we  = 0;

      tmp_read_data         = 32'h00000000;
      tmp_error             = 0;
      
      if (cs)
        begin
          if (we)
            begin
              case (address)
                // Write operations.
                CSPRNG_NUM_ROUNDS:
                  begin
                    csprng_num_rounds_new = write_data[5 : 0];
                    csprng_num_rounds_we  = 1;
                  end
                
                default:
                  begin
                    tmp_error = 1;
                  end
              endcase // case (address)
            end // if (we)

          else
            begin
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
                
                CSPRNG_NUM_ROUNDS:
                  begin
                    tmp_read_data = {26'h0000000, csprng_num_rounds_reg};
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
