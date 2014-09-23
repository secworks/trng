# Introduction to the Cryptech True Random Number Generator #
The Cryptech HSM project is designing an open HSM (Hardware Security or
High Security Module). 

A critical part of any HSM is the ability to generate high quality
random numbers. These numbers are used to generate cryptographic keys,
initial vectors, IDs and many other things.

In this introduction to the Cryptech True Random Number Generator (TRNG)
we will look at the design goals for the TRNG and how the design meets
these goals [1].

## Design Goals ##
The Cryptech TRNG shall meet the following design Goals 
1. High performance and Scaleable. 

2. Secure and Conservative. 

3. Modular.

4. Open, Testable and Auditable.


## High level architecture ##




## Notes and references ##

[1] Note: The Cryptech TRNG is in active development. The description
given in this introduction may include details that are still under
discussion, will be changed and/or has not yet been implemented. Also
note that the Cryptech TRNG is an open source design and the description
given here only covers the one shipped from:

http://trac.cryptech.is/


  
## Old stuff ##

But let me just try to explain how I'm thinking and why I belive it will
actually be pretty easy to add entropy sources, change the core used for
mixer (SHA-512 vs Keccak vs Blake vs ...) etc. If we ignore the debug
support I've been discussing with Berndt, the data path from entropy
source to generated random number look like this.

(1) The first stage consists of a number of entropy provider
modules. One for each entropy source used in a given
implementation. This means that there will be one to N entropy
providers. The entropy providers are digital HW within the FPGA and their purpose is to act like a driver for a given type of
entropy source. This means that they contain the interface logic to
control the entropy source and read sampled values. If the entropy
source is a PN avalanche noise source this means controlling the reverse
bias current and reading from the A/D to get ones and zeros. The entropy
provider might do whitening and will do on-line testing of collected
values to observe that the entropy source is at least not dead. The
entropy provider then collects these values into 32-bit words and feeds
them into a FIFO. This means that there is a FIFO at the output end of
each entropy provider and they are in a sense generic. The only
difference between two types of entropy providers is how many 32-bit
words they can provide in a given time. I'm sure that the FPGA entropy
source Berndt has been talking about could be wrapped into an entropy
provider like that. In short: All entropy sources have a companion
entropy provider core. Each entropy provider core is different in terms
of interface towards the entropy source. But the interface towards the
mixer is always the same.

(2) The mixer has a number of input ports,
each look the same - the read access interface to the FIFOs in the
entropy sources. The mixer looks at the FIFOs for available 32-bit words
and extracts them. The suggested way of doing this is round robin to get
fair queueing. In my implementation using SHA-512 i basically extracts
as many 32-bit words as needed to create a 1024 bit message block. This
is then fed into SHA-512 and processed. After X message blocks the
digest is extracted and fed into a FIFO. That is basically it for the
mixer. Shanging this to Keccak will change how many words are consumed
for each 512 bit word generated and how many cycles it takes. But the
interfaces does not have to change. And the only difference between
mixers are how many entropy sources it can use and thus how many
interfaces it has.


(3) The CSPRNG has a 512-bit interface connected to
the FIFO in the mixer. When it is time to reseed and there is a 512-bit
word available, it is extracted from the FIFO in the mixer and is used
to initalize the CSPRNG. The CSPRNG then starts generating random
numbers. These numbers are fed into a 32-bit FIFO which can be accessed
by the rest of the Cryptech system, applications (via calls into
Cryptech SW and down into HW register reads. In short, the CSPRNG
accepts 512 bit words and generates 32-bit words. How many cycles it
takes to generate new words and how often reseed happens depends on the
algorithm used, how the system is configured. But the interfaces should
be possible to keep the same. 
