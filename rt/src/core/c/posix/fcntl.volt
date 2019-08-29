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
/*!
 * @ingroup cbind
 * @ingroup posixbind
 */
module core.c.posix.fcntl;

version (Posix):

import core.c.posix.sys.types;


extern (C):

//
// Required
//
/*
F_DUPFD
F_GETFD
F_SETFD
F_GETFL
F_SETFL
F_GETLK
F_SETLK
F_SETLKW
F_GETOWN
F_SETOWN

FD_CLOEXEC

F_RDLCK
F_UNLCK
F_WRLCK

O_CREAT
O_EXCL
O_NOCTTY
O_TRUNC

O_APPEND
O_DSYNC
O_NONBLOCK
O_RSYNC
O_SYNC

O_ACCMODE
O_RDONLY
O_RDWR
O_WRONLY

struct flock
{
    short   l_type;
    short   l_whence;
    off_t   l_start;
    off_t   l_len;
    pid_t   l_pid;
}

int creat(in char*, mode_t);
int fcntl(int, int, ...);
int open(in char*, int, ...);
*/
version (Linux) {

    enum F_DUPFD        = 0;
    enum F_GETFD        = 1;
    enum F_SETFD        = 2;
    enum F_GETFL        = 3;
    enum F_SETFL        = 4;

    version (X86_64) {

        /+ static assert(typeid(off_t).size == 8); +/
        enum F_GETLK        = 5;
        enum F_SETLK        = 6;
        enum F_SETLKW       = 7;

    } else /+ static if( __USE_FILE_OFFSET64 ) {

        enum F_GETLK        = 12;
        enum F_SETLK        = 13;
        enum F_SETLKW       = 14;

    } else +/ {

        enum F_GETLK        = 5;
        enum F_SETLK        = 6;
        enum F_SETLKW       = 7;

    }

    enum F_GETOWN       = 9;
    enum F_SETOWN       = 8;

    enum FD_CLOEXEC     = 1;

    enum F_RDLCK        = 0;
    enum F_UNLCK        = 2;
    enum F_WRLCK        = 1;

    version (X86) {

        enum O_CREAT        = 0x40;     // octal     0100
        enum O_EXCL         = 0x80;     // octal     0200
        enum O_NOCTTY       = 0x100;    // octal     0400
        enum O_TRUNC        = 0x200;    // octal    01000

        enum O_APPEND       = 0x400;    // octal    02000
        enum O_NONBLOCK     = 0x800;    // octal    04000
        enum O_SYNC         = 0x101000; // octal 04010000
        enum O_DSYNC        = 0x1000;   // octal   010000
        enum O_RSYNC        = O_SYNC;

    } else version (X86_64) {

        enum O_CREAT        = 0x40;     // octal     0100
        enum O_EXCL         = 0x80;     // octal     0200
        enum O_NOCTTY       = 0x100;    // octal     0400
        enum O_TRUNC        = 0x200;    // octal    01000

        enum O_APPEND       = 0x400;    // octal    02000
        enum O_NONBLOCK     = 0x800;    // octal    04000
        enum O_SYNC         = 0x101000; // octal 04010000
        enum O_DSYNC        = 0x1000;   // octal   010000
        enum O_RSYNC        = O_SYNC;

    } else version (MIPS32) {

        enum O_CREAT        = 0x0100;
        enum O_EXCL         = 0x0400;
        enum O_NOCTTY       = 0x0800;
        enum O_TRUNC        = 0x0200;

        enum O_APPEND       = 0x0008;
        enum O_DSYNC        = O_SYNC;
        enum O_NONBLOCK     = 0x0080;
        enum O_RSYNC        = O_SYNC;
        enum O_SYNC         = 0x0010;

    } else version (MIPS64) {

        enum O_CREAT        = 0x0100;
        enum O_EXCL         = 0x0400;
        enum O_NOCTTY       = 0x0800;
        enum O_TRUNC        = 0x0200;

        enum O_APPEND       = 0x0008;
        enum O_DSYNC        = 0x0010;
        enum O_NONBLOCK     = 0x0080;
        enum O_RSYNC        = O_SYNC;
        enum O_SYNC         = 0x4010;

    } else version (PPC) {

        enum O_CREAT        = 0x40;     // octal     0100
        enum O_EXCL         = 0x80;     // octal     0200
        enum O_NOCTTY       = 0x100;    // octal     0400
        enum O_TRUNC        = 0x200;    // octal    01000

        enum O_APPEND       = 0x400;    // octal    02000
        enum O_NONBLOCK     = 0x800;    // octal    04000
        enum O_SYNC         = 0x101000; // octal 04010000
        enum O_DSYNC        = 0x1000;   // octal   010000
        enum O_RSYNC        = O_SYNC;

    } else version (PPC64) {

        enum O_CREAT        = 0x40;     // octal     0100
        enum O_EXCL         = 0x80;     // octal     0200
        enum O_NOCTTY       = 0x100;    // octal     0400
        enum O_TRUNC        = 0x200;    // octal    01000

        enum O_APPEND       = 0x400;    // octal    02000
        enum O_NONBLOCK     = 0x800;    // octal    04000
        enum O_SYNC         = 0x101000; // octal 04010000
        enum O_DSYNC        = 0x1000;   // octal   010000
        enum O_RSYNC        = O_SYNC;

    } else version (ARMHF) {

        enum O_CREAT        = 0x40;     // octal     0100
        enum O_EXCL         = 0x80;     // octal     0200
        enum O_NOCTTY       = 0x100;    // octal     0400
        enum O_TRUNC        = 0x200;    // octal    01000

        enum O_APPEND       = 0x400;    // octal    02000
        enum O_NONBLOCK     = 0x800;    // octal    04000
        enum O_SYNC         = 0x101000; // octal 04010000
        enum O_DSYNC        = 0x1000;   // octal   010000
        enum O_RSYNC        = O_SYNC;

    } else version (AArch64) {

        enum O_CREAT        = 0x40;     // octal     0100
        enum O_EXCL         = 0x80;     // octal     0200
        enum O_NOCTTY       = 0x100;    // octal     0400
        enum O_TRUNC        = 0x200;    // octal    01000

        enum O_APPEND       = 0x400;    // octal    02000
        enum O_NONBLOCK     = 0x800;    // octal    04000
        enum O_SYNC         = 0x101000; // octal 04010000
        enum O_DSYNC        = 0x1000;   // octal   010000
        enum O_RSYNC        = O_SYNC;

    } else version (SystemZ) {

        enum O_CREAT        = 0x40;     // octal     0100
        enum O_EXCL         = 0x80;     // octal     0200
        enum O_NOCTTY       = 0x100;    // octal     0400
        enum O_TRUNC        = 0x200;    // octal    01000

        enum O_APPEND       = 0x400;    // octal    02000
        enum O_NONBLOCK     = 0x800;    // octal    04000
        enum O_SYNC         = 0x101000; // octal 04010000
        enum O_DSYNC        = 0x1000;   // octal   010000
        enum O_RSYNC        = O_SYNC;

    } else {

        static assert(false, "unsupported arch");

    }

    enum O_ACCMODE      = 0x3;
    enum O_RDONLY       = 0x0;
    enum O_WRONLY       = 0x1;
    enum O_RDWR         = 0x2;

    struct flock
    {
        l_type: i16;
        l_whence: i16;
        l_start: off_t;
        l_len: off_t;
        l_pid: pid_t;
    }

/+    static if( __USE_FILE_OFFSET64 ) {

        int   creat64(in char*, mode_t);
		alias creat = creat64;

        int   open64(in char*, int, ...);
		alias open = open64;
    }+/
  //  else
//    {
        fn   creat(in char*, mode_t) i32;
        fn   open(in char*, i32, ...) i32;
  //  }

    enum AT_SYMLINK_NOFOLLOW = 0x100;
    enum AT_FDCWD = -100;

} else version (OSX) {

    enum F_DUPFD        = 0;
    enum F_GETFD        = 1;
    enum F_SETFD        = 2;
    enum F_GETFL        = 3;
    enum F_SETFL        = 4;
    enum F_GETOWN       = 5;
    enum F_SETOWN       = 6;
    enum F_GETLK        = 7;
    enum F_SETLK        = 8;
    enum F_SETLKW       = 9;

    enum FD_CLOEXEC     = 1;

    enum F_RDLCK        = 1;
    enum F_UNLCK        = 2;
    enum F_WRLCK        = 3;

    enum O_CREAT        = 0x0200;
    enum O_EXCL         = 0x0800;
    enum O_NOCTTY       = 0;
    enum O_TRUNC        = 0x0400;

    enum O_RDONLY       = 0x0000;
    enum O_WRONLY       = 0x0001;
    enum O_RDWR         = 0x0002;
    enum O_ACCMODE      = 0x0003;

    enum O_NONBLOCK     = 0x0004;
    enum O_APPEND       = 0x0008;
    enum O_SYNC         = 0x0080;
    //enum O_DSYNC
    //enum O_RSYNC

    struct flock
    {
        l_start: off_t;
        l_len: off_t;
        l_pid: pid_t;
        l_type: i16;
        l_whence: i16;
    }

    fn creat(in char*, mode_t) i32;
    fn open(in char*, i32, ...) i32;

}

fn fcntl(i32, i32, ...) i32;

// Generic Posix fallocate
fn posix_fallocate(i32, off_t, off_t) i32;

//
// Advisory Information (ADV)
//
/*
POSIX_FADV_NORMAL
POSIX_FADV_SEQUENTIAL
POSIX_FADV_RANDOM
POSIX_FADV_WILLNEED
POSIX_FADV_DONTNEED
POSIX_FADV_NOREUSE

int posix_fadvise(int, off_t, off_t, int);
*/
