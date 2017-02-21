// Copyright © 2005-2009, Sean Kelly.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
// File taken from druntime, and modified for Volt.
module core.c.signal;

version (!Metal):


extern(C):
@system:
nothrow:

// this should be volatile
alias sig_atomic_t = i32;

version (Windows) {

	//enum SIG_ERR    = cast(sigfn_t) -1;
	//enum SIG_DFL    = cast(sigfn_t) 0;
	//enum SIG_IGN    = cast(sigfn_t) 1;

	// standard C signals
	enum SIGABRT    = 22; // Abnormal termination
	enum SIGFPE     = 8;  // Floating-point error
	enum SIGILL     = 4;  // Illegal hardware instruction
	enum SIGINT     = 2;  // Terminal interrupt character
	enum SIGSEGV    = 11; // Invalid memory reference
	enum SIGTERM    = 15; // Termination

} else version(Posix) {

	//enum SIG_ERR    = cast(sigfn_t) -1;
	//enum SIG_DFL    = cast(sigfn_t) 0;
	//enum SIG_IGN    = cast(sigfn_t) 1;

	// standard C signals
	enum SIGABRT    = 6;  // Abnormal termination
	enum SIGFPE     = 8;  // Floating-point error
	enum SIGILL     = 4;  // Illegal hardware instruction
	enum SIGINT     = 2;  // Terminal interrupt character
	enum SIGSEGV    = 11; // Invalid memory reference
	enum SIGTERM    = 15; // Termination

} else {

	static assert(false, "not a supported platform");

}

fn signal(sig: i32, func: fn(i32)) fn(i32);
fn raise(sig: i32) i32;
