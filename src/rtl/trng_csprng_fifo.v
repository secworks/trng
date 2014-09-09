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
                        input wire           discard,
                        output wire          more_data,

                        output wire          rnd_syn,
                        output wire [31 : 0] rnd_data,
                        output wire          rnd_ack
                       );


  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter FIFO_DEPTH = 64;
  parameter FIFO_MAX = FIFO_DEPTH - 1;


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [31 : 0] fifo_mem [0 : FIFO_MAX];
  reg          fifo_mem_we;

  reg [3 : 0] mux_data_ptr_reg;
  reg [3 : 0] mux_data_ptr_new;
  reg         mux_data_ptr_inc;
  reg         mux_data_ptr_rst;
  reg         mux_data_ptr_we;

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

  reg [31 : 0] rnd_data_reg;

  reg          rnd_syn_reg;
  reg          rnd_syn_new;

  reg [1 : 0]  wr_ctrl_reg;
  reg [1 : 0]  wr_ctrl_new;
  reg          wr_ctrl_we;

  reg [1 : 0]  rd_ctrl_reg;
  reg [1 : 0]  rd_ctrl_new;
  reg          rd_ctrl_we;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign rnd_data = rnd_data_reg;
  assign rnd_syn  = rnd_syn_reg;


  //----------------------------------------------------------------
  // reg_update
  //----------------------------------------------------------------
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        begin
          mux_data_ptr_reg <= 4'h0;
          wr_ptr_reg       <= 8'h00;
          rd_ptr_reg       <= 8'h00;
          rnd_data_reg     <= 32'h00000000;
          rnd_syn_reg      <= 0;
        end
      else
        begin
          rnd_data_reg <= fifo_mem[rd_ptr_reg];
          rnd_syn_reg  <= rnd_syn_new;

          if (fifo_mem_we)
            begin
              fifo_mem[wr_ptr_reg] <= muxed_data;
            end

          if (mux_data_ptr_we)
            begin
              mux_data_ptr_reg <= mux_data_ptr_new;
            end

          if (wr_ptr_we)
            begin
              wr_ptr_reg <= wr_ptr_new;
            end

          if (rd_ptr_we)
            begin
              rd_ptr_reg <= rd_ptr_new;
            end
        end
    end // reg_update


  //----------------------------------------------------------------
  // data_mux
  //----------------------------------------------------------------
  always @*
    begin : data_mux
      case(mux_data_ptr_reg)
        00: muxed_data = csprng_data[031 : 000];
        01: muxed_data = csprng_data[063 : 032];
        02: muxed_data = csprng_data[095 : 064];
        03: muxed_data = csprng_data[127 : 096];
        04: muxed_data = csprng_data[159 : 128];
        05: muxed_data = csprng_data[191 : 160];
        06: muxed_data = csprng_data[223 : 192];
        07: muxed_data = csprng_data[255 : 224];
        08: muxed_data = csprng_data[287 : 256];
        09: muxed_data = csprng_data[313 : 282];
        10: muxed_data = csprng_data[351 : 320];
        11: muxed_data = csprng_data[383 : 351];
        12: muxed_data = csprng_data[415 : 384];
        13: muxed_data = csprng_data[447 : 416];
        14: muxed_data = csprng_data[479 : 448];
        15: muxed_data = csprng_data[511 : 480];
      endcase // case (mux_data_ptr_reg)
    end // data_mux


  //----------------------------------------------------------------
  // mux_data_ptr
  //----------------------------------------------------------------
  always @*
    begin : mux_data_ptr
      mux_data_ptr_new = 4'h0;
      mux_data_ptr_we  = 0;

      if (mux_data_ptr_rst)
        begin
          mux_data_ptr_new = 4'h0;
          mux_data_ptr_we  = 1;
        end

      if (mux_data_ptr_inc)
        begin
          mux_data_ptr_new = mux_data_ptr_reg + 1'b1;
          mux_data_ptr_we  = 1;
        end
    end // mux_data_ptr


  //----------------------------------------------------------------
  // fifo_rd_ptr
  //----------------------------------------------------------------
  always @*
    begin : fifo_rd_ptr
      rd_ptr_new = 8'h00;
      rd_ptr_we  = 0;

      if (rd_ptr_rst)
        begin
          rd_ptr_new = 8'h00;
          rd_ptr_we  = 1;
        end

      if (rd_ptr_inc)
        begin
          if (rd_ptr_reg == FIFO_MAX)
            begin
              rd_ptr_new = 8'h00;
              rd_ptr_we  = 1;
            end
          else
            begin
              rd_ptr_new = rd_ptr_reg + 1'b1
              rd_ptr_we  = 1;
            end
        end
    end // fifo_rd_ptr


  //----------------------------------------------------------------
  // fifo_wr_ptr
  //----------------------------------------------------------------
  always @*
    begin : fifo_wr_ptr
      wr_ptr_new = 8'h00;
      wr_ptr_we  = 0;

      if (wr_ptr_rst)
        begin
          wr_ptr_new = 8'h00;
          wr_ptr_we  = 1;
        end

      if (wr_ptr_inc)
        begin
          if (wrd_ptr_reg == FIFO_MAX)
            begin
              wr_ptr_new = 8'h00;
              wr_ptr_we  = 1;
            end
          else
            begin
              wr_ptr_new = wr_ptr_reg + 1'b1
              wr_ptr_we  = 1;
            end
        end
    end // fifo_wr_ptr


  //----------------------------------------------------------------
  //----------------------------------------------------------------
  always @*
    begin : rd_ctrl
    end // rd_ctrl


  //----------------------------------------------------------------
  //----------------------------------------------------------------
  always @*
    begin : wr_ctrl
    end // wr_ctrl
endmodule // trng_csprng_fifo

//======================================================================
// EOF trng_csprng_fifo.v
//======================================================================
