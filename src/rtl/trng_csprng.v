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
                   input wire [5 : 0]   num_rounds,
                   input wire           reseed,
                   output               error,
                   
                   // Seed input
                   input wire           seed_syn,
                   input [383 : 0]      seed_data,
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
  
  parameter CORE_NAME0         = 32'h73686132; // "sha2"
  parameter CORE_NAME1         = 32'h2d323536; // "-512"
  parameter CORE_VERSION       = 32'h302e3830; // "0.80"

  
  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------

  
  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg [31 : 0] tmp_read_data;
  reg          tmp_error;
  
  
  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign read_data = tmp_read_data;
  assign error     = tmp_error;
  
             
  //----------------------------------------------------------------
  // core instantiation.
  //----------------------------------------------------------------
  
  
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

        end
      else
        begin

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
      tmp_read_data = 32'h00000000;
      tmp_error     = 0;
      
      if (cs)
        begin
          if (we)
            begin
              case (address)
                // Write operations.
                
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
                    tmp_read_data = CORE_NAME0;
                  end

                ADDR_NAME1:
                  begin
                    tmp_read_data = CORE_NAME1;
                  end
                
                ADDR_VERSION:
                  begin
                    tmp_read_data = CORE_VERSION;
                  end
                
                default:
                  begin
                    tmp_error = 1;
                  end
              endcase // case (address)
            end
        end
    end // addr_decoder
endmodule // trng_csprng

//======================================================================
// EOF trng_csprng.
//======================================================================
