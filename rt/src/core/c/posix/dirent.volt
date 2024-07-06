// Copyright 2005-2009, Sean Kelly.
// SPDX-License-Identifier: BSL-1.0
// File taken from druntime, and modified for Volt.
/*!
 * @ingroup cbind
 * @ingroup posixbind
 */
module core.c.posix.dirent;

version (Posix):

private import core.c.posix.config;
public import core.c.posix.sys.types; // for ino_t


extern(C):
@system: // Not checked properly.
nothrow:

//
// Required
//
/*
DIR

struct dirent
{
    char[] d_name;
}

int     closedir(DIR*);
DIR*    opendir(in char*);
dirent* readdir(DIR*);
void    rewinddir(DIR*);
*/

version (Linux) {

	// NOTE: The following constants are non-standard Linux definitions
	//       for dirent.d_type.
	enum
	{
		DT_UNKNOWN  = 0,
		DT_FIFO     = 1,
		DT_CHR      = 2,
		DT_DIR      = 4,
		DT_BLK      = 6,
		DT_REG      = 8,
		DT_LNK      = 10,
		DT_SOCK     = 12,
		DT_WHT      = 14
	}

	struct dirent
	{
		d_ino: ino_t;
		d_off: off_t;
		d_reclen: u16;
		d_type: u8;
		d_name: char[256];
	}

	struct DIR
	{
		// Managed by OS
	}

	// static if (__USE_LARGEFILE64)
	version (none) {

		fn readdir64(DIR*) dirent*;
		alias readdir = readdir64;

	} else {

		fn readdir(DIR*) dirent*;

	}

	fn opendir(const(char)*) DIR*;
	fn closedir(DIR*) i32;

} else version (OSX) {

	enum
	{
		DT_UNKNOWN  = 0,
		DT_FIFO     = 1,
		DT_CHR      = 2,
		DT_DIR      = 4,
		DT_BLK      = 6,
		DT_REG      = 8,
		DT_LNK      = 10,
		DT_SOCK     = 12,
		DT_WHT      = 14
	}

	version (AArch64) {
		struct dirent
		{
			d_ino: ino_t;
			d_seekoff: u64;
			d_reclen: u16;
			d_namlen: u16;
			d_type: u8;
			d_name: char[1024];
		}
	} else {
		align(4) struct dirent
		{
			d_ino: ino_t;
			d_reclen: u16;
			d_type: u8;
			d_namelen: u8;
			d_name: char[256];
		}
	}

	struct DIR
	{
		// Managed by OS
	}

	fn readdir(DIR*) dirent*;
	fn opendir(const(char)*) DIR*;
	fn closedir(DIR*) i32;

}
//
// Thread-Safe Functions (TSF)
//
/*
int readdir_r(DIR*, dirent*, dirent**);
*/

version (Linux) {

	// static if (__USE_LARGEFILE64)
	version (none) {

		fn readdir64_r(DIR*, dirent*, dirent**) i32;
		alias readdir_r = readdir64_r;

	} else {

		fn readdir_r(DIR*, dirent*, dirent**) i32;

	}

} else version (OSX) {

	fn readdir_r(DIR*, dirent*, dirent**) i32;

} /+ else version (FreeBSD) {

	int readdir_r(DIR*, dirent*, dirent**);

}+/


//
// XOpen (XSI)
//
/*
void   seekdir(DIR*, c_long);
c_long telldir(DIR*);
*/

version (Linux) {

	fn seekdir(DIR*, c_long);
	fn telldir(DIR*) c_long;

}
