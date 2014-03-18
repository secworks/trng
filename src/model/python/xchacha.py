#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#=======================================================================
#
# xchacha.py
# ----------
# Simple model of the XChaCha stream cipher. Used as a reference for
# the HW implementation. Also used as part of the TRNG Python model.
# The code follows the structure of the HW implementation as much
# as possible.
#
# This model is heavily based on the chacha.py model in the
# Secworks ChaCha HW implementation.
#
# 
# Author: Joachim Strömbergson
# Copyright (c) 2014, Secworks Sweden AB
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or 
# without modification, are permitted provided that the following 
# conditions are met: 
# 
# 1. Redistributions of source code must retain the above copyright 
#    notice, this list of conditions and the following disclaimer. 
# 
# 2. Redistributions in binary form must reproduce the above copyright 
#    notice, this list of conditions and the following disclaimer in 
#    the documentation and/or other materials provided with the 
#    distribution. 
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE 
# COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, 
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#=======================================================================

#-------------------------------------------------------------------
# Python module imports.
#-------------------------------------------------------------------
import sys


#-------------------------------------------------------------------
# Constants.
#-------------------------------------------------------------------
TAU   = [0x61707865, 0x3120646e, 0x79622d36, 0x6b206574]
SIGMA = [0x61707865, 0x3320646e, 0x79622d32, 0x6b206574]


#-------------------------------------------------------------------
# ChaCha()
#-------------------------------------------------------------------
class XChaCha():
    
    #---------------------------------------------------------------
    # __init__()
    #
    # Given the key, iv initializes the state of the cipher.
    # The number of rounds used can be set. By default 8 rounds
    # are used. Accepts a list of either 16 or 32 bytes as key.
    # Accepts a list of 8 bytes as IV.
    #---------------------------------------------------------------
    def __init__(self, key, iv, rounds = 8, verbose = 0):
        self.state = [0] * 16
        self.x = [0] * 16
        self.rounds = rounds
        self.verbose = verbose
        self.set_key_iv(key, iv)
        

    #---------------------------------------------------------------
    # set_key_iv()
    # 
    # Set key and iv. Basically reinitialize the cipher.
    # This also resets the block counter.
    #---------------------------------------------------------------
    def set_key_iv(self, key, iv):
        keyword0 = self._b2w(key[0:4])
        keyword1 = self._b2w(key[4:8])
        keyword2 = self._b2w(key[8:12])
        keyword3 = self._b2w(key[12:16])
        
        if len(key) == 16:
            self.state[0]  = TAU[0]
            self.state[1]  = TAU[1]
            self.state[2]  = TAU[2]
            self.state[3]  = TAU[3]
            self.state[4]  = keyword0
            self.state[5]  = keyword1
            self.state[6]  = keyword2
            self.state[7]  = keyword3
            self.state[8]  = keyword0
            self.state[9]  = keyword1
            self.state[10] = keyword2
            self.state[11] = keyword3

        elif len(key) == 32:
            keyword4 = self._b2w(key[16:20])
            keyword5 = self._b2w(key[20:24])
            keyword6 = self._b2w(key[24:28])
            keyword7 = self._b2w(key[28:32])
            self.state[0]  = SIGMA[0]
            self.state[1]  = SIGMA[1]
            self.state[2]  = SIGMA[2]
            self.state[3]  = SIGMA[3]
            self.state[4]  = keyword0
            self.state[5]  = keyword1
            self.state[6]  = keyword2
            self.state[7]  = keyword3
            self.state[8]  = keyword4
            self.state[9]  = keyword5
            self.state[10] = keyword6
            self.state[11] = keyword7
        else:
            print("Key length of %d bits, is not supported." % (len(key) * 8))

        # Common state init for both key lengths.
        self.block_counter = [0, 0]
        self.state[12] = self.block_counter[0]
        self.state[13] = self.block_counter[1]
        self.state[14] = self._b2w(iv[0:4])
        self.state[15] = self._b2w(iv[4:8])

        if self.verbose:
            print("State after init:")
            self._print_state()
        

    #---------------------------------------------------------------
    # next()
    #
    # Encyp/decrypt the next block. This also updates the
    # internal state and increases the block counter.
    #---------------------------------------------------------------
    def next(self, data_in):
        # Copy the current internal state to the temporary state x.
        self.x = self.state[:]

        if self.verbose:
            print("State before round processing.")
            self._print_state()

        if self.verbose:
            print("X before round processing:")
            self._print_x()
        
        # Update the internal state by performing
        # (rounds / 2) double rounds.
        for i in range(int(self.rounds / 2)):
            if (self.verbose > 1):
                print("Doubleround 0x%02x:" % i)
            self._doubleround()
            if (self.verbose > 1):
                print("")
            
        if self.verbose:
            print("X after round processing:")
            self._print_x()

        # Update the internal state by adding the elements
        # of the temporary state to the internal state.
        self.state = [((self.state[i] + self.x[i]) & 0xffffffff) for i in range(16)]

        if self.verbose:
            print("State after round processing.")
            self._print_state()
        
        bytestate = []
        for i in self.state:
            bytestate += self._w2b(i)
        
        # Create the data out words.
        data_out = [data_in[i] ^ bytestate[i] for i in range(64)]

        # Update the block counter.
        self._inc_counter()
        
        return data_out


    #---------------------------------------------------------------
    # _doubleround()
    #
    # Perform the two complete rounds that comprises the
    # double round.
    #---------------------------------------------------------------
    def _doubleround(self):
        if (self.verbose > 0):
            print("Start of double round processing.")
        
        self._quarterround(0, 4,  8, 12)
        if (self.verbose > 1):
            print("X after QR 0")
            self._print_x()
        self._quarterround(1, 5,  9, 13)
        if (self.verbose > 1):
            print("X after QR 1")
            self._print_x()
        self._quarterround(2, 6, 10, 14)
        if (self.verbose > 1):
            print("X after QR 2")
            self._print_x()
        self._quarterround(3, 7, 11, 15)
        if (self.verbose > 1):
            print("X after QR 3")
            self._print_x()
        
        self._quarterround(0, 5, 10, 15)
        if (self.verbose > 1):
            print("X after QR 4")
            self._print_x()
        self._quarterround(1, 6, 11, 12)
        if (self.verbose > 1):
            print("X after QR 5")
            self._print_x()
        self._quarterround(2, 7,  8, 13)
        if (self.verbose > 1):
            print("X after QR 6")
            self._print_x()
        self._quarterround(3, 4,  9, 14)
        if (self.verbose > 1):
            print("X after QR 7")
            self._print_x()
            
        if (self.verbose > 0):
            print("End of double round processing.")

            
    #---------------------------------------------------------------
    #  _quarterround()
    #
    # Updates four elements in the state vector x given by
    # their indices.
    #---------------------------------------------------------------
    def _quarterround(self, ai, bi, ci, di):
        # Extract four elemenst from x using the qi tuple.
        a, b, c, d = self.x[ai], self.x[bi], self.x[ci], self.x[di]

        if (self.verbose > 1):
            print("Indata to quarterround:")
            print("X state indices:", ai, bi, ci, di)
            print("a = 0x%08x, b = 0x%08x, c = 0x%08x, d = 0x%08x" %\
                  (a, b, c, d))
            print("")
            
        a0 = (a + b) & 0xffffffff
        d0 = d ^ a0
        d1 = ((d0 << 16) + (d0 >> 16)) & 0xffffffff
        c0 = (c + d1) & 0xffffffff
        b0 = b ^ c0
        b1 = ((b0 << 12) + (b0 >> 20)) & 0xffffffff
        a1 = (a0 + b1) & 0xffffffff
        d2 = d1 ^ a1
        d3 = ((d2 << 8) + (d2 >> 24)) & 0xffffffff
        c1 = (c0 + d3) & 0xffffffff 
        b2 = b1 ^ c1
        b3 = ((b2 << 7) + (b2 >> 25)) & 0xffffffff 

        if (self.verbose > 2):
            print("Intermediate values:")
            print("a0 = 0x%08x, a1 = 0x%08x" % (a0, a1))
            print("b0 = 0x%08x, b1 = 0x%08x, b2 = 0x%08x, b3 = 0x%08x" %\
                  (b0, b1, b2, b3))
            print("c0 = 0x%08x, c1 = 0x%08x" % (c0, c1))
            print("d0 = 0x%08x, d1 = 0x%08x, d2 = 0x%08x, d3 = 0x%08x" %\
                  (d0, d1, d2, d3))
            print("")
        
        a_prim = a1
        b_prim = b3
        c_prim = c1
        d_prim = d3

        if (self.verbose > 1):
            print("Outdata from quarterround:")
            print("a_prim = 0x%08x, b_prim = 0x%08x, c_prim = 0x%08x, d_prim = 0x%08x" %\
                  (a_prim, b_prim, c_prim, d_prim))
            print("")
            
        # Update the four elemenst in x using the qi tuple.
        self.x[ai], self.x[bi] = a_prim, b_prim
        self.x[ci], self.x[di] = c_prim, d_prim


    #---------------------------------------------------------------
    # _inc_counter()
    #
    # Increase the 64 bit block counter.
    #---------------------------------------------------------------
    def _inc_counter(self):
        self.block_counter[0] += 1 & 0xffffffff
        if not (self.block_counter[0] % 0xffffffff):
            self.block_counter[1] += 1 & 0xffffffff


    #---------------------------------------------------------------
    # _b2w()
    #
    # Given a list of four bytes returns the little endian
    # 32 bit word representation of the bytes.
    #---------------------------------------------------------------
    def _b2w(self, bytes):
        return (bytes[0] + (bytes[1] << 8)
                + (bytes[2] << 16) + (bytes[3] << 24)) & 0xffffffff


    #---------------------------------------------------------------
    # _w2b()
    #
    # Given a 32-bit word returns a list of set of four bytes
    # that is the little endian byte representation of the word.
    #---------------------------------------------------------------
    def _w2b(self, word):
        return [(word & 0x000000ff), ((word & 0x0000ff00) >> 8),
                ((word & 0x00ff0000) >> 16), ((word & 0xff000000) >> 24)]


    #---------------------------------------------------------------
    # _print_state()
    #
    # Print the internal state.
    #---------------------------------------------------------------
    def _print_state(self):
        print(" 0: 0x%08x,  1: 0x%08x,  2: 0x%08x,  3: 0x%08x" %\
              (self.state[0], self.state[1], self.state[2], self.state[3]))
        print(" 4: 0x%08x,  5: 0x%08x,  6: 0x%08x,  7: 0x%08x" %\
              (self.state[4], self.state[5], self.state[6], self.state[7]))
        print(" 8: 0x%08x,  9: 0x%08x, 10: 0x%08x, 11: 0x%08x" %\
              (self.state[8], self.state[9], self.state[10], self.state[11]))
        print("12: 0x%08x, 13: 0x%08x, 14: 0x%08x, 15: 0x%08x" %\
              (self.state[12], self.state[13], self.state[14], self.state[15]))
        print("")


    #---------------------------------------------------------------
    # _print_x()
    #
    # Print the temporary state X.
    #---------------------------------------------------------------
    def _print_x(self):
        print(" 0: 0x%08x,  1: 0x%08x,  2: 0x%08x,  3: 0x%08x" %\
              (self.x[0], self.x[1], self.x[2], self.x[3]))
        print(" 4: 0x%08x,  5: 0x%08x,  6: 0x%08x,  7: 0x%08x" %\
              (self.x[4], self.x[5], self.x[6], self.x[7]))
        print(" 8: 0x%08x,  9: 0x%08x, 10: 0x%08x, 11: 0x%08x" %\
              (self.x[8], self.x[9], self.x[10], self.x[11]))
        print("12: 0x%08x, 13: 0x%08x, 14: 0x%08x, 15: 0x%08x" %\
              (self.x[12], self.x[13], self.x[14], self.x[15]))
        print("")


#-------------------------------------------------------------------
# print_block()
#
# Print a given block (list) of bytes ordered in
# rows of eight bytes.
#-------------------------------------------------------------------
def print_block(block):
    for i in range(0, len(block), 8):
        print("0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x" %\
              (block[i], block[i+1], block[i+2], block[i+3],
               block[i+4], block[i+5], block[i+6], block[i+7]))


#-------------------------------------------------------------------
# check_block()
#
# Compare the result block with the expected block and print
# if the result for the given test case was correct or not.
#-------------------------------------------------------------------
def check_block(result, expected, test_case):
    if result == expected:
        print("SUCCESS: %s was correct." % test_case)
    else:
        print("ERROR: %s was not correct." % test_case)
        print("Expected:")
        print_block(expected)
        print("")
        print("Result:")
        print_block(result)
    print("")

    
#-------------------------------------------------------------------
# main()
#
# If executed tests the ChaCha class using known test vectors.
#-------------------------------------------------------------------
def main():
    print("Testing the ChaCha Python model.")
    print("--------------------------------")
    print

    # Testing with TC1-128-8.
    # All zero inputs. IV all zero. 128 bit key, 8 rounds.
    print("TC1-128-8: All zero inputs. 128 bit key, 8 rounds.")
    key1 = [0x00] * 16
    iv1  = [0x00] * 8
    expected1 = [0xe2, 0x8a, 0x5f, 0xa4, 0xa6, 0x7f, 0x8c, 0x5d,
                 0xef, 0xed, 0x3e, 0x6f, 0xb7, 0x30, 0x34, 0x86,
                 0xaa, 0x84, 0x27, 0xd3, 0x14, 0x19, 0xa7, 0x29,
                 0x57, 0x2d, 0x77, 0x79, 0x53, 0x49, 0x11, 0x20,
                 0xb6, 0x4a, 0xb8, 0xe7, 0x2b, 0x8d, 0xeb, 0x85,
                 0xcd, 0x6a, 0xea, 0x7c, 0xb6, 0x08, 0x9a, 0x10,
                 0x18, 0x24, 0xbe, 0xeb, 0x08, 0x81, 0x4a, 0x42,
                 0x8a, 0xab, 0x1f, 0xa2, 0xc8, 0x16, 0x08, 0x1b]
    block1 = [0x00] * 64
    cipher1 = ChaCha(key1, iv1, verbose=0)
    result1 = cipher1.next(block1)
    check_block(result1, expected1, "TC1-128-8")
    print


    # Testing with TC1-128-12.
    # All zero inputs. IV all zero. 128 bit key, 12 rounds.
    print("TC1-128-12: All zero inputs. 128 bit key, 12 rounds.")
    key1 = [0x00] * 16
    iv1  = [0x00] * 8
    expected1 = [0xe1, 0x04, 0x7b, 0xa9, 0x47, 0x6b, 0xf8, 0xff,
                 0x31, 0x2c, 0x01, 0xb4, 0x34, 0x5a, 0x7d, 0x8c,
                 0xa5, 0x79, 0x2b, 0x0a, 0xd4, 0x67, 0x31, 0x3f,
                 0x1d, 0xc4, 0x12, 0xb5, 0xfd, 0xce, 0x32, 0x41,
                 0x0d, 0xea, 0x8b, 0x68, 0xbd, 0x77, 0x4c, 0x36,
                 0xa9, 0x20, 0xf0, 0x92, 0xa0, 0x4d, 0x3f, 0x95,
                 0x27, 0x4f, 0xbe, 0xff, 0x97, 0xbc, 0x84, 0x91,
                 0xfc, 0xef, 0x37, 0xf8, 0x59, 0x70, 0xb4, 0x50]
    block1 = [0x00] * 64
    cipher1 = ChaCha(key1, iv1, rounds = 12, verbose=0)
    result1 = cipher1.next(block1)
    check_block(result1, expected1, "TC1-128-12")
    print


    # Testing with TC1-128-20.
    # All zero inputs. IV all zero. 128 bit key, 20 rounds.
    print("TC1-128-20: All zero inputs. 128 bit key, 20 rounds.")
    key1 = [0x00] * 16
    iv1  = [0x00] * 8
    expected1 = [0x89, 0x67, 0x09, 0x52, 0x60, 0x83, 0x64, 0xfd,
                 0x00, 0xb2, 0xf9, 0x09, 0x36, 0xf0, 0x31, 0xc8,
                 0xe7, 0x56, 0xe1, 0x5d, 0xba, 0x04, 0xb8, 0x49,
                 0x3d, 0x00, 0x42, 0x92, 0x59, 0xb2, 0x0f, 0x46,
                 0xcc, 0x04, 0xf1, 0x11, 0x24, 0x6b, 0x6c, 0x2c,
                 0xe0, 0x66, 0xbe, 0x3b, 0xfb, 0x32, 0xd9, 0xaa,
                 0x0f, 0xdd, 0xfb, 0xc1, 0x21, 0x23, 0xd4, 0xb9,
                 0xe4, 0x4f, 0x34, 0xdc, 0xa0, 0x5a, 0x10, 0x3f]
    block1 = [0x00] * 64
    cipher1 = ChaCha(key1, iv1, rounds = 20, verbose=0)
    result1 = cipher1.next(block1)
    check_block(result1, expected1, "TC1-128-20")
    print


    # Testing with TC1-256-8.
    # All zero inputs. IV all zero. 256 bit key, 8 rounds.
    print("TC1-256-8: All zero inputs. 256 bit key, 8 rounds.")
    key1 = [0x00] * 32
    iv1  = [0x00] * 8
    expected1 = [0x3e, 0x00, 0xef, 0x2f, 0x89, 0x5f, 0x40, 0xd6,
                 0x7f, 0x5b, 0xb8, 0xe8, 0x1f, 0x09, 0xa5, 0xa1,
                 0x2c, 0x84, 0x0e, 0xc3, 0xce, 0x9a, 0x7f, 0x3b,
                 0x18, 0x1b, 0xe1, 0x88, 0xef, 0x71, 0x1a, 0x1e,
                 0x98, 0x4c, 0xe1, 0x72, 0xb9, 0x21, 0x6f, 0x41,
                 0x9f, 0x44, 0x53, 0x67, 0x45, 0x6d, 0x56, 0x19,
                 0x31, 0x4a, 0x42, 0xa3, 0xda, 0x86, 0xb0, 0x01,
                 0x38, 0x7b, 0xfd, 0xb8, 0x0e, 0x0c, 0xfe, 0x42]
    block1 = [0x00] * 64
    cipher1 = ChaCha(key1, iv1, verbose=0)
    result1 = cipher1.next(block1)
    check_block(result1, expected1, "TC1-256-8")
    print


    # Testing with TC1-256-12.
    # All zero inputs. IV all zero. 256 bit key, 12 rounds.
    print("TC1-256-12: All zero inputs. 256 bit key, 12 rounds.")
    key1 = [0x00] * 32
    iv1  = [0x00] * 8
    expected1 = [0x9b, 0xf4, 0x9a, 0x6a, 0x07, 0x55, 0xf9, 0x53,
                 0x81, 0x1f, 0xce, 0x12, 0x5f, 0x26, 0x83, 0xd5,
                 0x04, 0x29, 0xc3, 0xbb, 0x49, 0xe0, 0x74, 0x14,
                 0x7e, 0x00, 0x89, 0xa5, 0x2e, 0xae, 0x15, 0x5f,
                 0x05, 0x64, 0xf8, 0x79, 0xd2, 0x7a, 0xe3, 0xc0,
                 0x2c, 0xe8, 0x28, 0x34, 0xac, 0xfa, 0x8c, 0x79,
                 0x3a, 0x62, 0x9f, 0x2c, 0xa0, 0xde, 0x69, 0x19,
                 0x61, 0x0b, 0xe8, 0x2f, 0x41, 0x13, 0x26, 0xbe]
    block1 = [0x00] * 64
    cipher1 = ChaCha(key1, iv1, rounds = 12, verbose=0)
    result1 = cipher1.next(block1)
    check_block(result1, expected1, "TC1-256-12")
    print


    # Testing with TC1-256-20.
    # All zero inputs. IV all zero. 256 bit key, 20 rounds.
    print("TC1-256-20: All zero inputs. 256 bit key, 20 rounds.")
    key1 = [0x00] * 32
    iv1  = [0x00] * 8
    expected1 = [0x76, 0xb8, 0xe0, 0xad, 0xa0, 0xf1, 0x3d, 0x90,
                 0x40, 0x5d, 0x6a, 0xe5, 0x53, 0x86, 0xbd, 0x28,
                 0xbd, 0xd2, 0x19, 0xb8, 0xa0, 0x8d, 0xed, 0x1a,
                 0xa8, 0x36, 0xef, 0xcc, 0x8b, 0x77, 0x0d, 0xc7,
                 0xda, 0x41, 0x59, 0x7c, 0x51, 0x57, 0x48, 0x8d,
                 0x77, 0x24, 0xe0, 0x3f, 0xb8, 0xd8, 0x4a, 0x37,
                 0x6a, 0x43, 0xb8, 0xf4, 0x15, 0x18, 0xa1, 0x1c,
                 0xc3, 0x87, 0xb6, 0x69, 0xb2, 0xee, 0x65, 0x86]
    block1 = [0x00] * 64
    cipher1 = ChaCha(key1, iv1, rounds = 20, verbose=0)
    result1 = cipher1.next(block1)
    check_block(result1, expected1, "TC1-256-20")
    print

    
    # Testing with TC2-128-8.
    # Single bit set in key. IV all zero. 128 bit key.
    print("TC2-128-8: One bit in key set. IV all zeros. 128 bit key, 8 rounds.")
    key2 = [0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
    iv2  = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
    expected2 = [0x03, 0xa7, 0x66, 0x98, 0x88, 0x60, 0x5a, 0x07,
                 0x65, 0xe8, 0x35, 0x74, 0x75, 0xe5, 0x86, 0x73,
                 0xf9, 0x4f, 0xc8, 0x16, 0x1d, 0xa7, 0x6c, 0x2a,
                 0x3a, 0xa2, 0xf3, 0xca, 0xf9, 0xfe, 0x54, 0x49,
                 0xe0, 0xfc, 0xf3, 0x8e, 0xb8, 0x82, 0x65, 0x6a,
                 0xf8, 0x3d, 0x43, 0x0d, 0x41, 0x09, 0x27, 0xd5,
                 0x5c, 0x97, 0x2a, 0xc4, 0xc9, 0x2a, 0xb9, 0xda,
                 0x37, 0x13, 0xe1, 0x9f, 0x76, 0x1e, 0xaa, 0x14]
    block2 = [0x00] * 64
    cipher2 = ChaCha(key2, iv2, verbose=0)
    result2 = cipher2.next(block2)
    check_block(result2, expected2, "TC2-128-8")
    print

    
    # Testing with TC2-256-8.
    # Single bit set in key. IV all zero. 256 bit key.
    print("TC2-256-8: One bit in key set. IV all zeros. 256 bit key, 8 rounds.")
    key2 = [0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
    iv2  = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
    expected2 = [0xcf, 0x5e, 0xe9, 0xa0, 0x49, 0x4a, 0xa9, 0x61,
                 0x3e, 0x05, 0xd5, 0xed, 0x72, 0x5b, 0x80, 0x4b,
                 0x12, 0xf4, 0xa4, 0x65, 0xee, 0x63, 0x5a, 0xcc,
                 0x3a, 0x31, 0x1d, 0xe8, 0x74, 0x04, 0x89, 0xea,
                 0x28, 0x9d, 0x04, 0xf4, 0x3c, 0x75, 0x18, 0xdb,
                 0x56, 0xeb, 0x44, 0x33, 0xe4, 0x98, 0xa1, 0x23,
                 0x8c, 0xd8, 0x46, 0x4d, 0x37, 0x63, 0xdd, 0xbb,
                 0x92, 0x22, 0xee, 0x3b, 0xd8, 0xfa, 0xe3, 0xc8]
    block2 = [0x00] * 64
    cipher2 = ChaCha(key2, iv2, verbose=0)
    result2 = cipher2.next(block2)
    check_block(result2, expected2, "TC2-256-8")
    print

    
    # Testing with TC3-128-8.
    # All zero key. Single bit in IV set. 128 bit key.
    print("TC3-128-8: All zero key. Single bit in IV set. 128 bit key, 8 rounds.")
    key3 = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
    iv3  = [0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
    
    expected3 = [0x25, 0xf5, 0xbe, 0xc6, 0x68, 0x39, 0x16, 0xff,
                 0x44, 0xbc, 0xcd, 0x12, 0xd1, 0x02, 0xe6, 0x92,
                 0x17, 0x66, 0x63, 0xf4, 0xca, 0xc5, 0x3e, 0x71,
                 0x95, 0x09, 0xca, 0x74, 0xb6, 0xb2, 0xee, 0xc8,
                 0x5d, 0xa4, 0x23, 0x6f, 0xb2, 0x99, 0x02, 0x01,
                 0x2a, 0xdc, 0x8f, 0x0d, 0x86, 0xc8, 0x18, 0x7d,
                 0x25, 0xcd, 0x1c, 0x48, 0x69, 0x66, 0x93, 0x0d,
                 0x02, 0x04, 0xc4, 0xee, 0x88, 0xa6, 0xab, 0x35]
    block3 = [0x00] * 64
    cipher3 = ChaCha(key3, iv3, verbose=0)
    result3 = cipher3.next(block3)
    check_block(result3, expected3, "TC3-128-8")
    print

    
    # Testing with TC4-128-8.
    # All bits in key IV are set. 128 bit key, 8 rounds.
    print("TC4-128-8: All bits in key IV are set. 128 bit key, 8 rounds.")
    key4 = [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
            0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    iv4  = [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    expected4 = [0x22, 0x04, 0xd5, 0xb8, 0x1c, 0xe6, 0x62, 0x19,
                 0x3e, 0x00, 0x96, 0x60, 0x34, 0xf9, 0x13, 0x02,
                 0xf1, 0x4a, 0x3f, 0xb0, 0x47, 0xf5, 0x8b, 0x6e,
                 0x6e, 0xf0, 0xd7, 0x21, 0x13, 0x23, 0x04, 0x16,
                 0x3e, 0x0f, 0xb6, 0x40, 0xd7, 0x6f, 0xf9, 0xc3,
                 0xb9, 0xcd, 0x99, 0x99, 0x6e, 0x6e, 0x38, 0xfa,
                 0xd1, 0x3f, 0x0e, 0x31, 0xc8, 0x22, 0x44, 0xd3,
                 0x3a, 0xbb, 0xc1, 0xb1, 0x1e, 0x8b, 0xf1, 0x2d]
    block4 = [0x00] * 64
    cipher4 = ChaCha(key4, iv4, verbose=0)
    result4 = cipher4.next(block4)
    check_block(result4, expected4, "TC4-128-8")
    print

    
    # Testing with TC5-128-8
    print("TC5-128-8: Even bits set. 128 bit key, 8 rounds.")
    key5 = [0x55] * 16
    iv5  = [0x55] * 8
    expected5 = [0xf0, 0xa2, 0x3b, 0xc3, 0x62, 0x70, 0xe1, 0x8e,
                 0xd0, 0x69, 0x1d, 0xc3, 0x84, 0x37, 0x4b, 0x9b,
                 0x2c, 0x5c, 0xb6, 0x01, 0x10, 0xa0, 0x3f, 0x56,
                 0xfa, 0x48, 0xa9, 0xfb, 0xba, 0xd9, 0x61, 0xaa,
                 0x6b, 0xab, 0x4d, 0x89, 0x2e, 0x96, 0x26, 0x1b,
                 0x6f, 0x1a, 0x09, 0x19, 0x51, 0x4a, 0xe5, 0x6f,
                 0x86, 0xe0, 0x66, 0xe1, 0x7c, 0x71, 0xa4, 0x17,
                 0x6a, 0xc6, 0x84, 0xaf, 0x1c, 0x93, 0x19, 0x96]
    block5 = [0x00] * 64
    cipher5 = ChaCha(key5, iv5, verbose=0)
    result5 = cipher5.next(block5)
    check_block(result5, expected5, "TC5-128-8")
    print

    
    # Testing with TC6-128-8
    print("TC6-128-8: Odd bits set. 128 bit key, 8 rounds.")
    key6 = [0xaa] * 16
    iv6  = [0xaa] * 8
    expected6 = [0x31, 0x2d, 0x95, 0xc0, 0xbc, 0x38, 0xef, 0xf4,
                 0x94, 0x2d, 0xb2, 0xd5, 0x0b, 0xdc, 0x50, 0x0a,
                 0x30, 0x64, 0x1e, 0xf7, 0x13, 0x2d, 0xb1, 0xa8,
                 0xae, 0x83, 0x8b, 0x3b, 0xea, 0x3a, 0x7a, 0xb0,
                 0x38, 0x15, 0xd7, 0xa4, 0xcc, 0x09, 0xdb, 0xf5,
                 0x88, 0x2a, 0x34, 0x33, 0xd7, 0x43, 0xac, 0xed,
                 0x48, 0x13, 0x6e, 0xba, 0xb7, 0x32, 0x99, 0x50,
                 0x68, 0x55, 0xc0, 0xf5, 0x43, 0x7a, 0x36, 0xc6]
    block6 = [0x00] * 64
    cipher6 = ChaCha(key6, iv6, verbose=0)
    result6 = cipher6.next(block6)
    check_block(result6, expected6, "TC6-128-8")
    print

    
    # Testing with TC7-128-8
    print("TC7-128-8: Key and IV are increasing, decreasing patterns. 128 bit key, 8 rounds.")
    key7 = [0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
            0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]
    iv7  = [0x0f, 0x1e, 0x2d, 0x3c, 0x4b, 0x59, 0x68, 0x77]
    expected7 = [0xa7, 0xa6, 0xc8, 0x1b, 0xd8, 0xac, 0x10, 0x6e,
                 0x8f, 0x3a, 0x46, 0xa1, 0xbc, 0x8e, 0xc7, 0x02,
                 0xe9, 0x5d, 0x18, 0xc7, 0xe0, 0xf4, 0x24, 0x51,
                 0x9a, 0xea, 0xfb, 0x54, 0x47, 0x1d, 0x83, 0xa2,
                 0xbf, 0x88, 0x88, 0x61, 0x58, 0x6b, 0x73, 0xd2,
                 0x28, 0xea, 0xaf, 0x82, 0xf9, 0x66, 0x5a, 0x5a,
                 0x15, 0x5e, 0x86, 0x7f, 0x93, 0x73, 0x1b, 0xfb,
                 0xe2, 0x4f, 0xab, 0x49, 0x55, 0x90, 0xb2, 0x31]
    block7 = [0x00] * 64
    cipher7 = ChaCha(key7, iv7, verbose=2)
    result7 = cipher7.next(block7)
    check_block(result7, expected7, "TC7-128-8")
    print
    
    
    # Testing with TC8-128-8
    print("TC8-128-8: Random inputs. 128 bit key, 8 rounds.")
    key8 = [0xc4, 0x6e, 0xc1, 0xb1, 0x8c, 0xe8, 0xa8, 0x78,
            0x72, 0x5a, 0x37, 0xe7, 0x80, 0xdf, 0xb7, 0x35]
    iv8  = [0x1a, 0xda, 0x31, 0xd5, 0xcf, 0x68, 0x82, 0x21]
    expected8 = [0x6a, 0x87, 0x01, 0x08, 0x85, 0x9f, 0x67, 0x91,
                 0x18, 0xf3, 0xe2, 0x05, 0xe2, 0xa5, 0x6a, 0x68,
                 0x26, 0xef, 0x5a, 0x60, 0xa4, 0x10, 0x2a, 0xc8,
                 0xd4, 0x77, 0x00, 0x59, 0xfc, 0xb7, 0xc7, 0xba,
                 0xe0, 0x2f, 0x5c, 0xe0, 0x04, 0xa6, 0xbf, 0xbb,
                 0xea, 0x53, 0x01, 0x4d, 0xd8, 0x21, 0x07, 0xc0,
                 0xaa, 0x1c, 0x7c, 0xe1, 0x1b, 0x7d, 0x78, 0xf2,
                 0xd5, 0x0b, 0xd3, 0x60, 0x2b, 0xbd, 0x25, 0x94]
    block8 = [0x00] * 64
    cipher8 = ChaCha(key8, iv8, verbose=0)
    result8 = cipher8.next(block8)
    check_block(result8, expected8, "TC8-128-8")
    print


#-------------------------------------------------------------------
# __name__
# Python thingy which allows the file to be run standalone as
# well as parsed from within a Python interpreter.
#-------------------------------------------------------------------
if __name__=="__main__": 
    # Run the main function.
    sys.exit(main())

#=======================================================================
# EOF swchacha.py
#=======================================================================
