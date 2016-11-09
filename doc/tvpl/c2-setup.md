# Chapter 2 - Getting Set Up

The first thing to do with any programming environment is to install it and verify that it is working. So let's do that now.

## Installation

### Supported Platforms

At the time of writing *Volta*, Volt's compiler, has support for the following platforms:

* Linux (any architecture supported by [LLVM](http://llvm.org))
* Mac OS X (10.9 and higher)
* Microsoft Windows (7 and higher)

The source code is all available, so the absence of a platform is certainly no indication that it *does not* or *will not* work, only that Volta is not supported or tested there by the core maintainers. Pull requests welcome.

### Dependencies

*Volta* depends on [dmd](dlang.org), [llvm](llvm.org), and the [Boehm GC](http://www.hboehm.info/gc/). We'll also want [git](git-scm.com) to fetch the code. The next sections will detail how to install these for each platform.

#### Linux Dependency Installation

If you are on **Ubuntu** or a derivative,

	sudo apt-get install dmd llvm libgc-dev git

will install what you need. If you're on *Arch Linux*,

	sudo pacman -S dmd llvm

will do it. Otherwise consult your OS documentation on installing these packages.

#### OS X Dependency Installation

The easiest way of installing DMD is using [Homebrew](brew.sh). With brew installed,

	brew install dmd

If you prefer not to use Homebrew, then download DMD from [here](http://dlang.org/download.html), then just extract the contents of dmd.2..zip and set the DMD environmental variable to be "/osx/bin/dmd" or put the folder "/osx/bin" on the `$PATH`.

*TODO: Verify this.*

For LLVM version 3.9?, you can brew install `homebrew/versions/llvm39?`, then add `/usr/local/Cellar/llvm39/3.9.?/lib/llvm-3.9?/bin` on your $PATH (you may remove it afterwards). The reason for doing so is, that Homebrew doesn’t properly link non-core-only versions - like LLVM v3.9? if it comes from `homebrew/versions/llvm39?`. For example, `llvm-config` won’t be present, but only `llvm-config-3.9?`.

If you're not using Homebrew, download LLVM from the [LLVM homepage](llvm.org), and put the `bin` folder inside the unpacked tarball on the `$PATH`.

[You'll also need to install git.](https://git-scm.com/download/mac)

#### Windows Dependency Installation

*TODO: Run through steps in a VM, give more detail.*

[Install DMD.](dlang.org) Install Microsoft Visual Studio. Download the LLVM source code [from the homepage], and build it in 'Release' mode. Use the `make` application shipped with DMD from the Visual Studio.

Finally, [download and install git.](https://git-scm.com/download/win) Make sure it's on your `%PATH%`.

### Getting The Code

Now that the dependencies have been installed, let's set up a place to build *Volta*, and the tools it needs. For simplicity, this tutorial will assume this location is directly in your `$HOME` directory/User folder, but you can place it where you want.

	mkdir volt
	cd volt

Next, let's get the code for *Volta* (the compiler) and *Watt* (the standard library).

	git clone git@github.com:VoltLang/Volta.git
	git clone git@github.com:VoltLang/Watt.git

First, build *Volta*.

	cd Volta
	make

If the build was a success, there should be a `volt` or `volt.exe` executable in the `Volta` folder.

Create a `volt.conf` file in the `Volta` directory

	--if-stdlib
	%@execdir%/rt/libvrt-%@arch%-%@platform%.o
	--if-stdlib
	%@execdir%/../Watt/bin/libwatt-%@arch%-%@platform%.o
	--if-stdlib
	-I
	%@execdir%/rt/src
	--if-stdlib
	-I
	%@execdir%/../Watt/src
	--if-stdlib
	-l
	gc
	--if-stdlib
	--if-linux
	-l
	dl
	--if-stdlib
	--if-linux
	-l
	rt

Add `Volta` to your PATH to make things easier, and define the environmental variable `VOLTA` somewhere. On Linux and Mac OS X, you can define it in `~/.bashrc` or `~/.bash_profile` respectively:

	export VOLTA=~/volt/Volta/volt

As for Windows, you can create a system environmental variable from an admin command prompt and `setx`:

	setx VOLTA "C:\Users\You\volt\Volta\volt.exe"

Substituting the correct path to the `Volta` directory for your system.

Now we're all set up to build *Watt*.

	cd ../Watt
	make

And with that, you should have a working *Volta* install. To update it, just run `git pull` in the `Volta` and `Watt` directories, and re-run `make`. But let's make sure it's all working before moving on.

## Hello World!

### The Program

	import watt.io;
	
	fn main() i32
	{
		writefln("hello, world");
		return 0;
	}

### Compiling and Running

Save that code as `hello.volt`, then at your command prompt type `volt hello.volt`. This tells the compiler to compile the code in `hello.volt` into an executable. If there's no output, the compilation was successful. If an error is produced, make sure your code matches what's written above exactly. Otherwise, run `./a.out` (on Linux and OS X) or `a.exe` (on Windows) to run your new program! The message `hello, world` should be printed onto the screen. If it worked, everything seems to be setup correctly. [On to the next chapter!](c3-steps.html) If you're still confused, keep reading.

## Finding Help

In programming, as in life, things often don't work how you'd expect. Before you ask for help make sure you've tried to solve your problem on your own; problem solving is a key skill. But if you're truly stumped, the best place to ask for help is on the `#volt` IRC chat channel, hosted on [Freenode](https://webchat.freenode.net/). You can connect with a desktop client, or follow that link to use Freenode's own web client. 
