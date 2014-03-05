trng
====

True Random Number Generator core implemented in Verilog.

## Introduction ##
This repo contains the design of a True Random Number Generator (TRNG)
for the Cryptech OpenHSM project.


## Implementation details ##

The core supports multpiple entropy sources as well as a CSPRNG. For
each entropy source there are some estimators that checks that the
sources are not broken.

There are also an ability to extract raw entropy as well as inject test
data into the CSPRNG to verify the functionality.

The core will include one FPGA based entropy source but expects the
other entropy source(s) to be connected on external ports. It is up to
the user/system implementer to provide physical entropy souces. We will
suggest and provide info on how to design at least one such source.


## Status ##

***(2014-03-05)***

So far very little has been done. What will appear here soonish is a top
level wrapper with 32-bit interface to allow API development to start.


