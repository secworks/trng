//======================================================================
//
// trng_csprng_fifo.v
// ------------------
// Output FIFO for the CSPRNG in the TRNG.
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

module trng_csprng_fifo(
                        // Clock and reset.
                        input wire           clk,
                        input wire           reset_n,

                        input wire [511 : 0] csprng_data,
                        input wire           csprng_data_valid,
                        input wire           clear,
                        output wire          more_data,

                        output wire          rnd_syn,
                        output wire [31 : 0] rnd_data,
                        output wire          rnd_ack
                       );


  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter FIFO_DEPTH = 64;
  
                             
  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [31 : 0] fifo_mem[0 : (FIFO_DEPTH - 1)];

  reg [7 : 0] wr_ptr_reg;
  reg [7 : 0] wr_ptr_new;
  reg         wr_ptr_inc;
  reg         wr_ptr_rst;
  reg         wr_ptr_we;

  reg [7 : 0] rd_ptr_reg;
  reg [7 : 0] rd_ptr_new;
  reg         rd_ptr_inc;
  reg         rd_ptr_rst;
  reg         rd_ptr_we;
  

  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------


  //----------------------------------------------------------------
  // reg_update
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

  always @*
    begin : fifo_rd_ctr
      
    end
  
endmodule // trng_csprng_fifo

//======================================================================
// EOF trng_csprng_fifo.v
//======================================================================
