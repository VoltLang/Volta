// Copyright 2005-2009, Sean Kelly.
// SPDX-License-Identifier: BSL-1.0
// File taken from druntime, and modified for Volt.
/*!
 * @ingroup cbind
 * @ingroup stdcbind
 */
module core.c.time;

version (CRuntime_All):


private import core.c.config; // c_long


extern(C):
@trusted: // There are only a few functions here that use unsafe C strings.
nothrow:

version (Windows) {

	struct tm
	{
		tm_sec: i32;     // seconds after the minute - [0, 60]
		tm_min: i32;     // minutes after the hour - [0, 59]
		tm_hour: i32;    // hours since midnight - [0, 23]
		tm_mday: i32;    // day of the month - [1, 31]
		tm_mon: i32;     // months since January - [0, 11]
		tm_year: i32;    // years since 1900
		tm_wday: i32;    // days since Sunday - [0, 6]
		tm_yday: i32;    // days since January 1 - [0, 365]
		tm_isdst: i32;   // Daylight Saving Time flag
	}
} else version (OSX) {

	struct tm
	{
		tm_sec: i32;     // seconds after the minute [0-60]
		tm_min: i32;     // minutes after the hour [0-59]
		tm_hour: i32;    // hours since midnight [0-23]
		tm_mday: i32;    // day of the month [1-31]
		tm_mon: i32;     // months since January [0-11]
		tm_year: i32;    // years since 1900
		tm_wday: i32;    // days since Sunday [0-6]
		tm_yday: i32;    // days since January 1 [0-365]
		tm_isdst: i32;   // Daylight Savings Time flag
		tm_gmtoff: c_long;  // offset from CUT in seconds
		tm_zone: char*;    // timezone abbreviation
	}

} else version (Posix) {

	struct tm
	{
		tm_sec: i32;     // seconds after the minute [0-60]
		tm_min: i32;     // minutes after the hour [0-59]
		tm_hour: i32;    // hours since midnight [0-23]
		tm_mday: i32;    // day of the month [1-31]
		tm_mon: i32;     // months since January [0-11]
		tm_year: i32;    // years since 1900
		tm_wday: i32;    // days since Sunday [0-6]
		tm_yday: i32;    // days since January 1 [0-365]
		tm_isdst: i32;   // Daylight Savings Time flag
		tm_gmtoff: c_long;  // offset from CUT in seconds
		tm_zone: const(char)*;    // timezone abbreviation
	}

} else {

	static assert(false, "unsupported platform");

}

alias time_t = c_long;
alias clock_t = c_long;

version (Windows) {

	enum clock_t CLOCKS_PER_SEC = 1000;

} else version (Linux) {

	enum clock_t CLOCKS_PER_SEC = 1000000;

} else version (OSX) {

	enum clock_t CLOCKS_PER_SEC = 100;

} else version (FreeBSD) {

	enum clock_t CLOCKS_PER_SEC = 128;

}


fn clock() clock_t;
fn difftime(time1: time_t, time0: time_t) f64;
fn mktime(timeptr: tm*) time_t;
fn time(timer: time_t*) time_t;
fn asctime(in timeptr: tm*) char*;
fn ctime(in timer: time_t*) char*;
fn gmtime(in timer: time_t*) tm*;
fn localtime(in timer: time_t*) tm*;
@system fn strftime(s: char*, maxsize: size_t, in format: char*, in timeptr: tm*)  size_t;

version (Windows) {

	fn  tzset();                   // non-standard
	fn  _tzset();                  // non-standard
	@system fn _strdate(s: char*) char*; // non-standard
	@system fn _strtime(s: char*) char*; // non-standard

	//extern global const(char)*[2] tzname; // non-standard

} else version (Linux) {

	fn tzset();                         // non-standard
	//extern global const(char)*[2] tzname; // non-standard

} else version (OSX) {

	fn tzset();                         // non-standard
	//extern global const(char)*[2] tzname; // non-standard

} else {

	static assert(false, "not a supported platform");

}
