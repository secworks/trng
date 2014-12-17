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
#
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
BINARY_OUTPUT = False


#----------------------------------------------------------------
# I2C class
#----------------------------------------------------------------
# default configuration
I2C_dev = "/dev/i2c-2"
I2C_addr = 0x0f

# from /usr/include/linux/i2c-dev.h
I2C_SLAVE = 0x0703

def hexlist(list):
    return "[ " + ' '.join('%02x' % b for b in list) + " ]"

class I2C:
    # file handle for the i2c device
    file = None

    # constructor: initialize the i2c communications channel
    def __init__(self, dev=I2C_dev, addr=I2C_addr):
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
# test-case class
#----------------------------------------------------------------
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

class TcError(Exception):
    pass

class tc:
    def __init__(self, i2c, addr0, addr1):
        self.i2c = i2c
        self.addr0 = addr0
        self.addr1 = addr1

    def send_write_cmd(self, data):
        buf = [SOC, WRITE_CMD, self.addr0, self.addr1]
        for s in (24, 16, 8, 0):
            buf.append(data >> s & 0xff)
        buf.append(EOC)
        self.i2c.write(buf)

    def send_read_cmd(self):
        buf = [SOC, READ_CMD, self.addr0, self.addr1, EOC]
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
                raise TcError()
            elif (i == 1):        # response code
                try:
                    # anonymous dictionary of message lengths
                    len = {READ_OK:9, WRITE_OK:5, RESET_OK:3, ERROR:4, UNKNOWN:4}[b]
                except KeyError:  # unknown response code
                    # we've gotten out of sync, and there's probably nothing we can do
                    print "unknown response code 0x%02x" % b
                    raise TcError()
            buf.append(b)
            i += 1
        if DEBUG:
            print "read  %s" % hexlist(buf)
        return buf

    def get_expected(self, expected):
        buf = self.get_resp()
        if (buf != expected):
            print "expected %s,\nreceived %s" % (hexlist(expected), hexlist(buf))
            # raise TcError()

    def get_write_resp(self):
        expected = [SOR, WRITE_OK, self.addr0, self.addr1, EOR]
        self.get_expected(expected)

    def get_read_resp(self, data):
        expected = [SOR, READ_OK, self.addr0, self.addr1]
        for s in (24, 16, 8, 0):
            expected.append(data >> s & 0xff)
        expected.append(EOR)
        self.get_expected(expected)

    def write(self, data):
        self.send_write_cmd(data)
        self.get_write_resp()

    def read(self, data):
        self.send_read_cmd()
        self.get_read_resp(data)

    def read2(self, data):
        self.send_read_cmd()
        self.get_read_resp()

# Helper functions that use the tc class.
def tc_write(i2c, prefix, addr, data):
    tc(i2c, prefix, addr).write(data)

def tc_read(i2c, prefix, addr, data):
    tc(i2c, prefix, addr).read(data)

def tc_init(i2c, addr0):
    tc(i2c, addr0, ADDR_CTRL).write(CTRL_INIT_CMD)

def tc_next(i2c, addr0):
    tc(i2c, addr0, ADDR_CTRL).write(CTRL_NEXT_CMD)

def tc_wait(i2c, addr0, status):
    t = tc(i2c, addr0, ADDR_STATUS)
    while 1:
        t.send_read_cmd()
        buf = t.get_resp()
        if ((buf[7] & status) == status):
            break

def tc_wait_ready(i2c, addr0):
    tc_wait(i2c, addr0, STATUS_READY_BIT)

def tc_wait_valid(i2c, addr0):
    tc_wait(i2c, addr0, STATUS_VALID_BIT)



#----------------------------------------------------------------
#----------------------------------------------------------------
# Avalanche entropy tests

AVALANCHE_ADDR_PREFIX      = 0x20
AVALANCHE_NOISE            = 0x20
AVALANCHE_DELTA            = 0x30

def avalanche_read(i2c, addr, data):
    tc_read(i2c, AVALANCHE_ADDR_PREFIX, addr, data)

def avalanche_write(i2c, addr, data):
    tc_write(i2c, AVALANCHE_ADDR_PREFIX, addr, data)


# TC11 Read name and version from Avalanche core.
def TC11(i2c):
    print "TC1: Reading name, type and version words from SHA-1 core."

    avalanche_read(i2c, ADDR_NAME0,   0x73686131)    # "sha1"
    avalanche_read(i2c, ADDR_NAME1,   0x20202020)    # "    "
    avalanche_read(i2c, ADDR_VERSION, 0x302e3530)    # "0.50"


# TC12 Read noise from Avalanche core.
def TC12(i2c):
    for i in range(10):
        avalanche_read(i2c, AVALANCHE_NOISE,   0xffffffff)



#----------------------------------------------------------------
#----------------------------------------------------------------
# TRNG tests
TRNG_PREFIX       = 0x00
TRNG_ADDR_NAME0   = 0x00
TRNG_ADDR_NAME1   = 0x01
TRNG_ADDR_VERSION = 0x02
ENT1_PREFIX       = 0x05
ENT2_PREFIX       = 0x06
CSPRNG_PREFIX     = 0x0b
CSPRNG_DATA       = 0x20
ENT1_DATA         = 0x20
ENT2_DATA         = 0x20

def general_read(i2c, prefix, addr, data):
    tc_read(i2c, prefix, addr, data)

def general_write(i2c, prefix, addr, data):
    tc_write(i2c, prefix, addr, data)


# TC13 Read name and version from TRNG core.
def TC13(i2c):
    print "TC13: Reading name, type and version words from TRNG."

    general_read(i2c, TRNG_PREFIX, TRNG_ADDR_NAME0,   0x74726e67)
    general_read(i2c, TRNG_PREFIX, TRNG_ADDR_NAME1,   0x20202020)
    general_read(i2c, TRNG_PREFIX, TRNG_ADDR_VERSION, 0x302e3031)


# TC14 Read random numbers from TRNG core.
def TC14(i2c):
    print "TC14: Reading TRNG data."
    for i in range(20):
        general_read(i2c, CSPRNG_PREFIX, CSPRNG_DATA,   0xffffffff)

# TC15 Read entropy numbers from TRNG core avalanche noise entropy provider.
def TC15(i2c):
    print "TC15: Reading avalanche data."
    for i in range(20):
        general_read(i2c, ENT1_PREFIX, ENT1_DATA,   0xffffffff)


#----------------------------------------------------------------
#----------------------------------------------------------------
# TC16 Read entropy numbers from TRNG core ROSC noise entropy provider.
def TC16(i2c):
    print "TC15: Reading rosc data."
    for i in range(20000000):
        general_read(i2c, ENT2_PREFIX, ENT2_DATA,   0xffffffff)


#----------------------------------------------------------------
# main
#----------------------------------------------------------------
def main():

#    get_avalanche_entropy()
#    get_avalanche_delta()

    get_rosc_entropy()
    get_rosc_raw()

    get_rng_data()


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
