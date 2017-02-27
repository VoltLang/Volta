// Copyright © 2005-2009, Sean Kelly.
// See copyright notice in src/watt/license.d (BOOST ver. 1.0).
// File taken from druntime, and modified for Volt.
module core.c.posix.time;

version (!Metal):

private import core.c.posix.config;
public import core.c.time;
public import core.c.posix.sys.types;
//public import core.posix.signal; // for sigevent

version (Posix):
extern (C):

//
// Required (defined in core.stdc.time)
//
/*
char* asctime(in tm*);
clock_t clock();
char* ctime(in time_t*);
double difftime(time_t, time_t);
tm* gmtime(in time_t*);
tm* localtime(in time_t*);
time_t mktime(tm*);
size_t strftime(char*, size_t, in char*, in tm*);
time_t time(time_t*);
*/

version (Linux) {
	fn timegm(tm*) time_t;
} else version (OSX) {
	fn timegm(tm*) time_t;
} else {
	static assert(false, "Unsupported platform");
}

//
// C Extension (CX)
// (defined in core.stdc.time)
//
/*
char* tzname[];
void tzset();
*/

//
// Process CPU-Time Clocks (CPT)
//
/*
int clock_getcpuclockid(pid_t, clockid_t*);
*/

//
// Clock Selection (CS)
//
/*
int clock_nanosleep(clockid_t, int, in timespec*, timespec*);
*/

//
// Monotonic Clock (MON)
//
/*
CLOCK_MONOTONIC
*/

version (Linux) {
	enum CLOCK_MONOTONIC        = 1;
	enum CLOCK_MONOTONIC_RAW    = 4; // non-standard
	enum CLOCK_MONOTONIC_COARSE = 6; // non-standard
} else version (OSX) {
	// No CLOCK_MONOTONIC defined
} else {
	static assert(0);
}

//
// Timer (TMR)
//
/*
CLOCK_PROCESS_CPUTIME_ID (TMR|CPT)
CLOCK_THREAD_CPUTIME_ID (TMR|TCT)

NOTE: timespec must be defined in core.sys.posix.signal to break
	  a circular import.

struct timespec
{
	time_t  tv_sec;
	int     tv_nsec;
}

struct itimerspec
{
	timespec it_interval;
	timespec it_value;
}

CLOCK_REALTIME
TIMER_ABSTIME

clockid_t
timer_t

int clock_getres(clockid_t, timespec*);
int clock_gettime(clockid_t, timespec*);
int clock_settime(clockid_t, in timespec*);
int nanosleep(in timespec*, timespec*);
int timer_create(clockid_t, sigevent*, timer_t*);
int timer_delete(timer_t);
int timer_gettime(timer_t, itimerspec*);
int timer_getoverrun(timer_t);
int timer_settime(timer_t, int, in itimerspec*, itimerspec*);
*/

version (Linux) {
	enum CLOCK_PROCESS_CPUTIME_ID = 2;
	enum CLOCK_THREAD_CPUTIME_ID  = 3;

	struct timespec
	{
		tv_sec: time_t;
		tv_nsec: c_long;
	}

	struct itimerspec
	{
		it_interval: timespec;
		it_value: timespec;
	}

	enum CLOCK_REALTIME         = 0;
	enum CLOCK_REALTIME_COARSE  = 5; // non-standard
	enum TIMER_ABSTIME          = 0x01;

	alias clockid_t = i32;
	alias timer_t = i32;

	fn clock_getres(clockid_t, timespec*) i32;
	fn clock_gettime(clockid_t, timespec*) i32;
	fn clock_settime(clockid_t, in timespec*) i32;
	fn nanosleep(in timespec*, timespec*) i32;
	//int timer_create(clockid_t, sigevent*, timer_t*);
	fn timer_delete(timer_t) i32;
	fn timer_gettime(timer_t, itimerspec*) i32;
	fn timer_getoverrun(timer_t) i32;
	fn timer_settime(timer_t, i32, in itimerspec*, itimerspec*) i32;
} else version (OSX) {
	fn nanosleep(in void*, void*) i32;
} else {
	static assert(false, "Unsupported platform");
}

//
// Thread-Safe Functions (TSF)
//
/*
char* asctime_r(in tm*, char*);
char* ctime_r(in time_t*, char*);
tm*   gmtime_r(in time_t*, tm*);
tm*   localtime_r(in time_t*, tm*);
*/

version (Linux) {
	fn asctime_r(in tm*, char*) char*;
	fn ctime_r(in time_t*, char*) char*;
	fn gmtime_r(in time_t*, tm*) tm*;
	fn localtime_r(in time_t*, tm*) tm*;
} else version (OSX) {
	fn asctime_r(in tm*, char*) char*;
	fn ctime_r(in time_t*, char*) char*;
	fn gmtime_r(in time_t*, tm*) tm*;
	fn localtime_r(in time_t*, tm*) tm*;
} else {
	static assert(false, "Unsupported platform");
}

//
// XOpen (XSI)
//
/*
getdate_err

int daylight;
int timezone;

tm* getdate(in char*);
char* strptime(in char*, in char*, tm*);
*/

version (Linux) {
	extern global daylight: i32;
	extern global timezone: c_long;

	fn getdate(in char*) tm*;
	fn strptime(in char*, in char*, tm*) char*;
} else version (OSX) {
	extern global timezone: c_long;
	extern global daylight: i32;

	fn getdate(in char*) tm*;
	fn strptime(in char*, in char*, tm*) char*;
} else {
	static assert(false, "Unsupported platform");
}
