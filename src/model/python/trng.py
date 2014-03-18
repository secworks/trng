#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#=======================================================================
#
# trng.py
# -------
# Python model of the Cryptech True Random Number Generator (TRNG).
# The purpose of the model is to test deign decisions and evaluate
# parameters etc.
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
import xchacha
import hashlib
import random


#-------------------------------------------------------------------
# Constants.
#-------------------------------------------------------------------


#-------------------------------------------------------------------
# TRNG()
#-------------------------------------------------------------------
class TRNG():
    
    #---------------------------------------------------------------
    # __init__()
    #
    #---------------------------------------------------------------
    def __init__(self, verbosity = 0):
        self.verbosity = verbosity
        self.key    = [0x00] * 32
        self.iv     = [0x00] * 8
        self.rounds = 24
        self.mixer  = hashlib.sha512()
        self.csprng = xchacha.XChaCha(self.key, self.iv, self.rounds, self.verbosity)
        
        if self.verbosity > 0:
            print("TRNG started...")
            print("")

    
#-------------------------------------------------------------------
# main()
#-------------------------------------------------------------------
def main():
    print("Running the Cryptech TRNG model.")
    print("--------------------------------")
    print("")

    my_trng = TRNG(verbosity = 1)

    print("TRNG model done.")
    print("")


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
