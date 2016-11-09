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

	$ sudo apt-get install dmd llvm libgc-dev git-essentials

will install what you need. If you're on *Arch Linux*,

	$ sudo pacman -S dmd llvm

will do it. Otherwise consult your OS documentation on installing these packages.

#### OS X Dependency Installation

#### Windows Dependency Installation

### Getting The Code

Now that the dependencies have been installed, let's set up a place to build *Volta*, and the tools it needs. For simplicity, this tutorial will assume this location is directly in your `$HOME` directory, but you can place it where you want.

	$ mkdir volt
	$ cd volt

Next, let's get the code for *Volta* (the compiler) and *Watt* (the standard library).

	$ git clone git@github.com:VoltLang/Volta.git
	$ git clone git@github.com:VoltLang/Watt.git

## Uninstallation

### Linux Uninstallation

### OS X Uninstallation

### Windows Uninstallation

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
