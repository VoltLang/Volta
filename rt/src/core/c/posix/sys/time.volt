/**
 * From the D header file for POSIX.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Sean Kelly, Alex Rønne Petersen
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.c.posix.sys.time;

version (Posix):

public import core.c.posix.sys.types;  // for time_t, suseconds_t


extern (C):

//
// XOpen (XSI)
//
/*
struct timeval
{
    time_t      tv_sec;
    suseconds_t tv_usec;
}

struct itimerval
{
    timeval it_interval;
    timeval it_value;
}

ITIMER_REAL
ITIMER_VIRTUAL
ITIMER_PROF

int getitimer(int, itimerval*);
int gettimeofday(timeval*, void*);
int select(int, fd_set*, fd_set*, fd_set*, timeval*); (defined in core.sys.posix.sys.signal)
int setitimer(int, in itimerval*, itimerval*);
int utimes(in char*, ref const(timeval)[2]); // LEGACY
*/

alias tv_sec_t = time_t;
alias tv_usec_t = suseconds_t;

version (Linux) {
	
    struct timeval
    {
        tv_sec: time_t;
        tv_usec: suseconds_t;
    }

    struct itimerval
    {
        it_interval: timeval;
        it_value: timeval;
    }

    enum ITIMER_REAL    = 0;
    enum ITIMER_VIRTUAL = 1;
    enum ITIMER_PROF    = 2;

    fn getitimer(i32, itimerval*) i32;
    fn gettimeofday(timeval*, void*) i32;
    fn setitimer(i32, in itimerval*, itimerval*) i32;
    fn utimes(in char*, ref const(timeval)[2]) i32; // LEGACY

} else version (OSX) {

    struct timeval
    {
        tv_sec: time_t;
        tv_usec: suseconds_t;
    }

    struct itimerval
    {
        it_interval: timeval;
        it_value: timeval;
    }

    // non-standard
    struct timezone_t
    {
        tz_minuteswest: i32;
        tz_dsttime: i32;
    }

    fn getitimer(i32, itimerval*) i32;
    fn gettimeofday(timeval*, timezone_t*) i32; // timezone_t* is normally void*
    fn setitimer(i32, in itimerval*, itimerval*) i32;
    fn utimes(in char*, ref const(timeval)[2]) i32;

}
