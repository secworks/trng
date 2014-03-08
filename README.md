trng
====

True Random Number Generator core implemented in Verilog.

## Introduction ##
This repo contains the design of a True Random Number Generator (TRNG)
for the [Cryptech OpenHSM](http://cryptech.is/) project.


## Design inspiration, ideas and principles ##

The TRNG **MUST** be a really good one. Furthermore it must be trustable
by its users. That means it should not do wild and crazy stuff. And
users should be able to verify that the TRNG works as expected.

* Follow best practice
* Be conservative - No big untested ideas.
* Support transparency - The parts should be testable.


Some of our inspiration comes from:

* The Yarrow implementation in FreeBSD

* The Fortuna RNG by Ferguson and Schneier as described in Cryptography
Engineering.

* /dev/random in OpenBSD


## System description ##

The TRNG consists of a chain with three main subsystems

* Entropy generation
* Entropy accumulation
* Random generation


### Entropy generation ###

The entropy generation subsystems consists of at least two separate entropy
generators. Each generator collects entropy from an independent physical
process. The entropy sources MUST be of different types. For example
avalance noise from a reversed bias P/N junction as one source and RSSI
LSB from a receiver.

The reason for having multiple entropy sources is both to provide
reduncancy as well as making it harder for an attacker to affect the
entropy collection by forcing the attacker to try and affect different
physical processes simultaneously.

A given entropy generator is responsible for collecting the entropy
(possibly including A/D conversion.). The entropy generator MUST
implement some on-line testing of the physical entropy source based on
the entropy collected. The tests shall be described in detail here but
will at least include tests for:

* No long run lengths in generated values.
* Variance that exceeds a given threshhold.
* Mean value that don't deviate from expected mean.
* Frequency for all possible values are within expected variance.

If the tests fails over a period of generated values the entropy source
MUST raise an error flag. And MAY also block access to the entropy it
otherwise provides.

There shall also be possible to read out the raw entropy collected from
a given entropy generator. This MUST ONLY be possible in a specific
debug mode when no random generation is allowed. Also the entropy
provided in debug mode MUST NOT be used for later random number
generation. 

The entropy generator SHALL perform whitening on the collected entropy
before providing it as 32-bit values to the entropy accumulator.



### Entropy accumulation ###

The entropy acculumation subsystems reads 32-bit words from the entropy
generators. The 32-bit words are combined and mixed by a simple
XOR-mixer into 32-bit words accumulated.

(TODO: We need a mechanism for mixing that supports generators with
different rates, capacity.)

When 1024 bits of mixed entropy has been collected the entropy is used
as a message block fed into a hash function.

The hash function used is SHA-512 (NIST FIPS 180-4).

When at least 256 blocks have been processed the current 512 bit digest
from SHA-512 is possible to extract from the entropy accumulator as seed
for the random generator.

Note that the number of 256 bit blocks used to generate the digest can
and probably will be much higher. The 256 block limit is the lower
warm-up bound. This lower bound may be increased as needed to provide
more trust. The complete TRNG MUST NOT be able to generate any random
numbers before the warm-up bound has been met and the random generator
has been seeded.


### Random generation ###

The random generation consists of a symmetric cipher that generates a
stream of values based on an intial state from the seed provived by the
entropy accumulator.

Our proposal is to use the ChaCha stream cipher with 256 bit key and 96
bit IV. The key and IV are taken from the seed. This means that there
will be a 32 bit counter and thus the maximum number of keystream blocks
is (2**32 - 1). The cipher must then be reseeded and the counter be
reset. We propose that it will be possible to configure the maximum
number of blocks to generate. From 2**16 to (2**31 - 1).

The number of rounds used in ChaCha should be conservatively
selected. We propose that the number of rounds shall be at least 24
rounds. Possibly 32 rounds. Given the performance in HW for ChaCha and
the size of the keystream block, the TRNG should be able to generate
plentiful of random values even with 32 rounds.



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


## API ##


## Status ##

***(2014-03-05)***

So far very little has been done. What will appear here soonish is a top
level wrapper with 32-bit interface to allow API development to start.


