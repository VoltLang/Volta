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

Volt uses LLVM as a backend to generate binary code. Version 3.6.x is the least
supported version.


Linux
*****

For Linux's with GDC packaged (like Ubuntu) it is the recommended compiler.
To get GDC and LLVM on Ubuntu do this:

::

  $ sudo apt-get install gdc llvm

For DMD known working are DMD 2.067.1 and above. To setup DMD just follow the
Mac instructions.

Some versions of LLVM on Linux depend on being linked with tinfo, but don't tell llvm-config that. If you see a link failure involving del_setterm or similar, add -ltinfo to the LLVM_LDFLAGS variable in the GNUMakefile.

Mac
***

There are no packages of GDC for Mac so DMD should be used. To install it,
the easiest way is using `Homebrew <http://brew.sh>`_. If you don't have it,
install it from http://brew.sh

Then, in a terminal : ::

  brew install dmd
  
If you prefer not to use Homebrew, then download DMD from : http://dlang.org/download.html, 
then just extract the contents of dmd.2.<version>.zip <somewhere> and set the 
DMD environmental variable to be "<somewhere>/osx/bin/dmd" or put the folder 
"<somewhere>/osx/bin" on the path.

For LLVM version 3.6, you can :code:`brew install homebrew/versions/llvm36`, then
add :code:`/usr/local/Cellar/llvm36/3.6.2/lib/llvm-3.6/bin` on your $PATH (you may
remove it afterwards). The reason for doing so is, that Homebrew doesn't properly 
link non-core-only versions - like LLVM v3.6 if it comes from :code:`homebrew/versions/llvm36`. For example, :code:`llvm-config` won't be callable, 
but only :code:`llvm-config-3.6`.

Without Homebrew, just download LLVM from the LLVM homepage, and put the bin folder 
inside the unpacked tarball on the PATH, the builds system needs :code:`llvm-config` and the
compiler requires some helpers from there to link.

Volt also requires the Boehm GC : ::

  brew install bdw-gc

Or, without Homebrew : ::

  curl http://www.hboehm.info/gc/gc_source/gc-7.4.2.tar.gz -o gc-7.4.2.tar.gz
  tar xfv gc-7.4.2.tar.gz 
  cd gc-7.4.2
  git clone git://github.com/ivmai/libatomic_ops.git
  ./configure 
  make -j9
  
Then, copy :code:`libgc.la` and :code:`libcord.la` to the :code:`rt` folder.

Finally, run :code:`make` and :code:`make run`. If the latter exits with Error 42, you're all set up !


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
