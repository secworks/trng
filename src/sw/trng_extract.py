#!/usr/bin/env python
# -*- coding: utf-8 -*-
#=======================================================================
#
# trng_extract.py
# --------------
# This program extracts data values from the trng. The program supports
# reading from the entropy providers as well as the rng output.
# Extraxted data can be delivered in text or binary form. The code is
# based on code from the Cryptech project written by Paul Selkirk and
# Joachim Strömbergson
#
# Author: Joachim Strömbergson, Paul Sekirk
# Copyright (c) 2014, Secworks Sweden AB (Secworks)
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
import io
import fcntl
import argparse


#-------------------------------------------------------------------
# Defines.
#-------------------------------------------------------------------

# addresses and codes common to all hash cores
ADDR_NAME0       = 0x00
ADDR_NAME1       = 0x01
ADDR_VERSION     = 0x02
ADDR_CTRL        = 0x08
CTRL_INIT_CMD    = 1
CTRL_NEXT_CMD    = 2
ADDR_STATUS      = 0x09
STATUS_READY_BIT = 0
STATUS_VALID_BIT = 1

VERBOSE       = False
DEBUG         = False
BINARY_OUTPUT = True

AVALANCHE_ADDR_PREFIX      = 0x20
AVALANCHE_NOISE            = 0x20
AVALANCHE_DELTA            = 0x30

# TRNG tests
TRNG_PREFIX       = 0x00
TRNG_ADDR_NAME0   = 0x00
TRNG_ADDR_NAME1   = 0x01
TRNG_ADDR_VERSION = 0x02
ENT1_PREFIX       = 0x05
CSPRNG_PREFIX     = 0x0b
CSPRNG_DATA       = 0x20

ENT2_PREFIX       = 0x06
ENT1_DATA         = 0x20
ENT2_CTRL         = 0x10
ENT2_STATUS       = 0x11
ENT2_ENT_DATA     = 0x20
ENT2_ENT_RAW      = 0x21
ENT2_ROSC_OUT     = 0x22

# command codes
SOC                   = 0x55
EOC                   = 0xaa
READ_CMD              = 0x10
WRITE_CMD             = 0x11
RESET_CMD             = 0x01

# response codes
SOR                   = 0xaa
EOR                   = 0x55
READ_OK               = 0x7f
WRITE_OK              = 0x7e
RESET_OK              = 0x7d
UNKNOWN               = 0xfe
ERROR                 = 0xfd

# from /usr/include/linux/i2c-dev.h
I2C_SLAVE = 0x0703

# Number of 32 bit data words extracted in a run.
NUM_WORDS = 40000000


#----------------------------------------------------------------
# hexlist()
#----------------------------------------------------------------
def hexlist(list):
    return "[ " + ' '.join('%02x' % b for b in list) + " ]"


#----------------------------------------------------------------
# I2C class
#----------------------------------------------------------------
# default configuration
I2C_dev = "/dev/i2c-2"
I2C_addr = 0x0f

class I2C:
    # file handle for the i2c device
    file = None

    # constructor: initialize the i2c communications channel
    def __init__(self, dev, addr):
        self.dev = dev
        self.addr = addr
        try:
            self.file = io.FileIO(self.dev, 'r+b')
        except IOError as e:
            print "Unable to open %s: %s" % (self.dev, e.strerror)
            sys.exit(1)
        try:
            fcntl.ioctl(self.file, I2C_SLAVE, self.addr)
        except IOError as e:
            print "Unable to set I2C slave device 0x%02x: %s" % (self.addr, e.strerror)
            sys.exit(1)

    # destructor: close the i2c communications channel
    def __del__(self):
        if (self.file):
            self.file.close()

    # write a command to the i2c device
    def write(self, buf):
        if DEBUG:
            print "write %s" % hexlist(buf)
        self.file.write(bytearray(buf))

    # read one response byte from the i2c device
    def read(self):
        # read() on the i2c device will only return one byte at a time,
        # and tc.get_resp() needs to parse the response one byte at a time
        return ord(self.file.read(1))



#----------------------------------------------------------------
# Commerror()
#
# Empty class exception eater.
#----------------------------------------------------------------
class Commerror(Exception):
    pass


#----------------------------------------------------------------
# Comm
#
# Class for communicating with the HW.
#----------------------------------------------------------------
class Comm:
    def __init__(self):
        self.i2c = I2C(I2C_dev, I2C_addr)

    def send_write_cmd(self, prefix, addr, data):
        buf = [SOC, WRITE_CMD, prefix, addr]
        for s in (24, 16, 8, 0):
            buf.append(data >> s & 0xff)
        buf.append(EOC)
        self.i2c.write(buf)

    def send_read_cmd(self, prefix, addr):
        buf = [SOC, READ_CMD, prefix, addr, EOC]
        self.i2c.write(buf)

    def get_resp(self):
        buf = []
        len = 2
        i = 0
        while i < len:
            b = self.i2c.read()
            if ((i == 0) and (b != SOR)):
                # we've gotten out of sync, and there's probably nothing we can do
                print "response byte 0: expected 0x%02x (SOR), got 0x%02x" % (SOR, b)
                raise CommError()
            elif (i == 1):        # response code
                try:
                    # anonymous dictionary of message lengths
                    len = {READ_OK:9, WRITE_OK:5, RESET_OK:3, ERROR:4, UNKNOWN:4}[b]
                except KeyError:  # unknown response code
                    # we've gotten out of sync, and there's probably nothing we can do
                    print "unknown response code 0x%02x" % b
                    raise CommError()
            buf.append(b)
            i += 1
        if DEBUG:
            print "read  %s" % hexlist(buf)
        return buf

    def write_data(self, prefix, addr, data):
        self.send_write_cmd(prefix, addr, data)
        return self.get_resp()

    def read_data(self, prefix, addr):
        self.send_read_cmd(prefix, addr)
        return self.get_resp()


#----------------------------------------------------------------
# print_data()
#
# Print either text or binary data to std out.
#----------------------------------------------------------------
def print_data(my_data):
    my_bytes = my_data[4 : 8]

    if (BINARY_OUTPUT):
        for my_byte in my_bytes:
            sys.stdout.write(chr(my_byte))

    else:
        print("0x%02x 0x%02x 0x%02x 0x%02x" % 
              (my_bytes[0], my_bytes[1], my_bytes[2], my_bytes[3]))


#----------------------------------------------------------------
# wait_ready()
#
# Wait for the ready bit in the status register for the
# given core to be set accessible via the given device.
#----------------------------------------------------------------
def wait_ready(dev, prefix, addr):
    my_status = False
    while not my_status:
        my_status = dev.read_data(prefix, addr)[7]
        if VERBOSE:
            print("Status: %s" % my_status)


#----------------------------------------------------------------
# get_avalanche_entropy()
#----------------------------------------------------------------
def get_avalanche_entropy(dev):
    if VERBOSE:
        print "Reading avalanche entropy data."

    for i in range(NUM_WORDS):
        dev.read_data(ENT1_PREFIX, ENT1_DATA)


#----------------------------------------------------------------
# get_rosc_entropy()
#----------------------------------------------------------------
def get_rosc_entropy(dev):
    if VERBOSE:
        print "Reading rosc entropy data."

#    for i in range(NUM_WORDS):
    for i in range(10):
        wait_ready(dev, ENT2_PREFIX, ENT2_STATUS)
        my_data = dev.read_data(ENT2_PREFIX, ENT2_ENT_DATA)
        print_data(my_data)


#----------------------------------------------------------------
# looptest()
#
# Simple test that loops a large number of times to see
# if the ready bit is ever cleared.
#----------------------------------------------------------------
def looptest(dev):
    print("TRNG name: ", my_commdev.read_data(TRNG_PREFIX, TRNG_ADDR_NAME0))
    print("ENT2 status: ", my_commdev.read_data(ENT2_PREFIX, ENT2_STATUS))

    for i in range(100000000):
        ent_data = dev.read_data(ENT2_PREFIX, ENT2_ENT_DATA)
        ent_status = dev.read_data(ENT2_PREFIX, ENT2_STATUS)
        if not ent_status[7]:
            print("Got: %d" % ent_status[7])

#----------------------------------------------------------------
# main
#----------------------------------------------------------------
def main():
    if VERBOSE:
        print("Starting trng data extraction.")

    my_commdev = Comm()

    # looptest(my_commdev)

#    get_avalanche_entropy()
#    get_avalanche_delta()
    
    get_rosc_entropy(my_commdev)
#    get_rosc_raw()

#    get_rng_data()


#-------------------------------------------------------------------
# __name__
# Python thingy which allows the file to be run standalone as
# well as parsed from within a Python interpreter.
#-------------------------------------------------------------------
if __name__=="__main__":
    # Run the main function.
    sys.exit(main())

#=======================================================================
# EOF trng_extract.py
#=======================================================================
