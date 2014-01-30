====
Volt
====

Getting started
===============

Dependencies
------------

As Volt is written in D, a compiler for D is needed. GDC, LDC and DMD should
be able to compile Volt. Once Volt is capable enough the compiler will be
ported to Volt and become self-hosting.

Volt uses LLVM as backend to generate binary code. Currently version 3.1 is
used, version 3.0 might work, 2.9 will not as it is missing some interfaces.


Linux
*****

For Linux's with GDC packaged (like Ubuntu) it is the recommended compiler.
To get GDC and LLVM on Ubuntu do this:

::

  $ sudo apt-get install gdc llvm

For DMD known working are DMD 2.060 and above. To setup DMD just follow the
Mac instructions.


Mac
***

There are no packages of GDC for Mac so DMD should be used. To install it
just extract the contents of dmd.2.<version>.zip <somewhere> and set the
DMD environmental variable to be "<somewhere>/osx/bin/dmd" or put the folder
"<somewhere>/osx/bin" on the path.

Download llvm from the llvm homepage, and put the bin folder inside the
unpacked tarball on the PATH, the builds system needs llvm-config and the
compiler requires some helpers from there to link.


Windows
*******

The only compiler that has been used to compile Volta on Windows is DMD.
Install DMD and MinGW. Using MinGW's bash prompt, compile LLVM -- be sure
to use --enable-shared and build a DLL.

Once compiled, put the LLVM tools and DLL in your PATH, in with the D tools
is probably the simplest place. Run `implib /p:64 LLVM.lib <thellvmdll>` and
place that in the Volta directory. Run make (the digital mars one, not MinGW)
and with a bit of luck, you should have a working volt.exe. 

Other
*****

For other platforms you need probably need to compile it you can get the
latest version from here https://bitbucket.org/goshawk/gdc/wiki/Home
Cross compiling on Linux to Windows is confirmed working.


Building
--------

Now you just need to build the compiler, to do so type:

::

  $ make


Running
-------

::

  $ make run


Contributing
============

Please feel free to contribute. Contributing is easy! Just send us your code.
Diffs are appreciated, in git format; Github pull requests are excellent.

Things to consider:

 * The parser, runtime and standard library is under the BOOST license. Your
   contributions to any of these parts will be under that same license. If this
   isn't acceptable, then your code cannot be merged. This is really the only
   hard condition.
 * That was short wasn't it? Just remember don't be a dick, have fun and there
   will be cake! That is all!
