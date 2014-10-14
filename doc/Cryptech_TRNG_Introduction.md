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

1. High performance and Scaleable. Even a compact, low cost
implementation shall be able to generate 10-100 Mbps rate of random
number data. The design shall also be scaleable to basically arbitrarily
high capacity demands. A data rate of 100 Gbps for example shall be
possibe to reach, albeit not in a low cost implementation.


2. Secure and Conservative. Secure defaults. Following best practices
and don't invent new things that breaks with known besr practice. Very
high quality of the generated number. Resistance against attepmts at
manipulation. Use of big seed state. On-line testing of entropy souces.


3. Flexible and Modular. The architecture and the parameters controlling
the functionality shall be under control of the application. The major
functionaloties are in separate modules.


4. Open, Testable and Auditable.


Combining (4) with (2) and (3) is probably what sets the Cryptech TRNG
apart from many other designs.


## High level architecture ##

The Cryptech TRNG is a hybrid design with entropy providers connected to
physical entropy sources are used to seed a cryptographically safe
pseudor random number generator (CSPRNG). In order to combine the
entropy from the providers, the TRNG contains a mixer stage between the
providers and the CSPRNG. Figure XYZ shows the high level architecture.

Besides the three stages of the datapath, the TRNG contains a control
part that provides the functionality needed to test and debug the TRNG
in a secure manner, even in a running system.

The followin sub chapters will give a detailed description of each of
the parts of the TRNG.


### Entropy Providers ###

Entropy providers can be seen as the HW equivalent to drivers in an
operating system. The entropy provider is responsible for hiding the
functionality needed to control and extract data from a given entropy
source and to provide it as 32-bit data in a uniform way to the mixer.

The entropy provider must observe the behaviour of its noise source and
perform

Fast total failure tests and more comprehensive online test.


For debugging purposes the entropy providers must provide access to the
raw digital noise.



### Mixer ###

The mixer also decouples the random number generation from the entropy
collection. This means that the TRNG can collect entropy for the next
seed operation while the random generatio part keeps generating random
numbers.

The mixer is based around a cryptographic hash function. The current
implementation uses SHA-512 [5] but can be replaced with any other
cryptographic hash function.

Using a cryptographic hash function as a mixer makes it very hard
(infeasible) to determine the entropy from the seed. This makes it very
hard from an attacker to determine how an attempt at manipulating a
entropy source affected the seed and thus how effective the manipulatio
was.

Entropy is provided to the Mixer as 32-bit data words. The words are
accepted by the mixer in strict round robin order. This means that in an
implementation with a high capacity entropy provider and a lowe capacity
entropy provider, the rate of accepted data words from the high capacity
provider will be limited to the capacity of the low capacit
provider. The high capacity provider is simply not allowed to dominate
the input to the mixer.

Unless the TRNG state is reset, the hash function is never
reinitialized. Instead all entropy are added as new blocks of the same
message and the extracted seeds are intermediate digests generated for
each block added.

This means that the state of the hash function between seed data blocks
are based not only on the new entropy data, but also on previous hash
operations.

Each hash block is 1024 bits of new entropy, which are needed when
calculating one digest. A reseed requires two separate digests which
means that we need two blocks for a total of 2048 bits of entropy is
needd to reseed the CSPRNG.

The seeds are provided to the CSPRNG as 512 bit data words.


### CSPRNG ###

The CSPRNG is responsible for generating the random numbers provided to
applications by the TRNG.

The Cryptech CSPRNG is based on the stream cipher ChaCha. The key length
is 256 bits and the default number of rounds is 20. Users that want to
trade performance against security can adjust the numver of rounds by
setting the appropriate control registers.

The number of 512 bit blocks of random numbers generated is set to
64'h1000000000000000, or 2**60. This means that 2**64 32-bit words will
be generated between reseeds. The number of blocks between reseeds can
be adjusted by writing the the appropriate control register. It is also
possible to write to a control register that forces a reseed directly.

The CSPRNG requires two 512 bit words from the mixer to seed the
CSPRNG. These bits are used for:

- 512 bits block
- 256 bits key
- 64 bits IV
- 64 bits initial counter value.

In total 896 bits are used to seed the PRNG.

The current implementation of the CSPRNG contains one instance of the
ChaCha stream cipher. For higher performance more instances ca be added
to allow interleaved generation of random number blocks.

The CSPRNG contains a random number FIFO that provides the generated
32-bit numbers to applications. This allows the CSPRNG to generate
blocks of data fairly independently of the application consumption, and
ensure a steady rate of random numbers.


### Test and Debug ###








## Security motivation ##


## Implementation details ##
State.



## Implementation results ##
Size and performance in some FPGA devices.



## Notes and references ##

[1] Note: The Cryptech TRNG is in active development. The description
given in this introduction may include details that are still under
discussion, will be changed and/or has not yet been implemented. Also
note that the Cryptech TRNG is an open source design and the description
given here only covers the one shipped from:

http://trac.cryptech.is/

[2] SHA-512/x

[3] ChaCha stream cipher

[4] The Cryptech HSM Source Code: http://trac.cryptech.is/browser/core/trng

[5] NIST. FIPS 180-4.


## Old stuff ##
