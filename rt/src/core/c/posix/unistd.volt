/**
 * D header file for POSIX, modified for Volt.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Sean Kelly
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
module core.c.posix.unistd;

version (Posix):

private import core.c.posix.config;
private import core.c.stddef;
//public import core.posix.inttypes;  // for intptr_t
public import core.c.posix.sys.types; // for ssize_t, uid_t, gid_t, off_t, pid_t, useconds_t


extern (C):
nothrow:
//@nogc:

enum STDIN_FILENO  = 0;
enum STDOUT_FILENO = 1;
enum STDERR_FILENO = 2;

extern global optarg: char*;
extern global optind: i32;
extern global opterr: i32;
extern global optopt: i32;

fn access(in char*, i32) i32;
fn alarm(u32) u32;
fn chdir(in char*) i32;
fn chown(in char*, uid_t, gid_t) i32;
fn close(i32) i32;
fn confstr(i32, char*, size_t) size_t;
fn dup(i32) i32;
fn dup2(i32, i32) i32;
fn execl(in char*, in char*, ...) i32;
fn execle(in char*, in char*, ...) i32;
fn execlp(in char*, in char*, ...) i32;
fn execv(in char*, in char**) i32;
fn execve(in char*, in char**, in char**) i32;
fn execvp(in char*, in char**) i32;
fn _exit(i32);
fn fchown(i32, uid_t, gid_t) i32;
fn fork() pid_t;
fn fpathconf(i32, i32) c_long;
//int     ftruncate(int, off_t);
fn getcwd(char*, size_t) char*;
fn getegid() gid_t;
fn geteuid() uid_t;
fn getgid() gid_t;
fn getgroups(i32, gid_t*) i32;
fn gethostname(char*, size_t) i32;
fn getlogin() char*;
fn getlogin_r(char*, size_t) i32;
fn getopt(i32, in char**, in char*) i32;
fn getpgrp() pid_t;
fn getpid() pid_t;
fn getppid() pid_t;
fn getuid() uid_t;
fn isatty(i32) i32;
fn link(in char*, in char*) i32;
//off_t   lseek(int, off_t, int);
fn pathconf(in char*, i32) c_long;
fn pause() i32;
fn pipe(ref i32[2]) i32;
fn read(i32, void*, size_t) ssize_t;
fn readlink(in char*, char*, size_t) ssize_t;
fn rmdir(in char*) i32;
fn setegid(gid_t) i32;
fn seteuid(uid_t) i32;
fn setgid(gid_t) i32;
fn setpgid(pid_t, pid_t) i32;
fn setsid() pid_t;
fn setuid(uid_t) i32;
fn sleep(u32) u32;
fn symlink(in char*, in char*) i32;
fn sysconf(i32) c_long;
fn tcgetpgrp(i32) pid_t;
fn tcsetpgrp(i32, pid_t) i32;
fn ttyname(i32) char*;
fn ttyname_r(i32, char*, size_t) i32;
fn unlink(in char*) i32;
fn write(i32, in void*, size_t) ssize_t;
fn waitpid(pid_t, i32*, i32) pid_t;

version (Linux) {

//  static if( __USE_FILE_OFFSET64 )
//  {
//    off_t lseek64(int, off_t, int) /*@trusted*/;
//    alias lseek64 lseek;
//  }
//  else
//  {
	fn lseek(i32, off_t, i32) off_t;
//  }
//  static if( __USE_LARGEFILE64 )
//  {
//    int   ftruncate64(int, off_t) /*@trusted*/;
//    alias ftruncate64 ftruncate;
//  }
//  else
//  {
	fn ftruncate(i32, off_t) i32;
//  }

} /+ else version (Solaris) {

    version ( D_LP64 )
    {
        off_t   lseek(int, off_t, int) /*@trusted*/;
        alias   lseek lseek64;

        int     ftruncate(int, off_t) /*@trusted*/;
        alias   ftruncate ftruncate64;
    }
    else
    {
        static if( __USE_LARGEFILE64 )
        {
            off64_t lseek64(int, off64_t, int) /*@trusted*/;
            alias   lseek64 lseek;

            int     ftruncate64(int, off64_t) /*@trusted*/;
            alias   ftruncate64 ftruncate;
        }
        else
        {
            off_t   lseek(int, off_t, int) /*@trusted*/;
            int     ftruncate(int, off_t) /*@trusted*/;
        }
    }

} +/ else version (OSX) {

	fn lseek(i32, off_t, i32) off_t;
	fn ftruncate(i32, off_t) i32;

}

version (Linux) {

    enum F_OK       = 0;
    enum R_OK       = 4;
    enum W_OK       = 2;
    enum X_OK       = 1;

    enum F_ULOCK    = 0;
    enum F_LOCK     = 1;
    enum F_TLOCK    = 2;
    enum F_TEST     = 3;

    enum
    {
        _CS_PATH,

        _CS_V6_WIDTH_RESTRICTED_ENVS,

        _CS_GNU_LIBC_VERSION,
        _CS_GNU_LIBPTHREAD_VERSION,

        _CS_LFS_CFLAGS = 1000,
        _CS_LFS_LDFLAGS,
        _CS_LFS_LIBS,
        _CS_LFS_LINTFLAGS,
        _CS_LFS64_CFLAGS,
        _CS_LFS64_LDFLAGS,
        _CS_LFS64_LIBS,
        _CS_LFS64_LINTFLAGS,

        _CS_XBS5_ILP32_OFF32_CFLAGS = 1100,
        _CS_XBS5_ILP32_OFF32_LDFLAGS,
        _CS_XBS5_ILP32_OFF32_LIBS,
        _CS_XBS5_ILP32_OFF32_LINTFLAGS,
        _CS_XBS5_ILP32_OFFBIG_CFLAGS,
        _CS_XBS5_ILP32_OFFBIG_LDFLAGS,
        _CS_XBS5_ILP32_OFFBIG_LIBS,
        _CS_XBS5_ILP32_OFFBIG_LINTFLAGS,
        _CS_XBS5_LP64_OFF64_CFLAGS,
        _CS_XBS5_LP64_OFF64_LDFLAGS,
        _CS_XBS5_LP64_OFF64_LIBS,
        _CS_XBS5_LP64_OFF64_LINTFLAGS,
        _CS_XBS5_LPBIG_OFFBIG_CFLAGS,
        _CS_XBS5_LPBIG_OFFBIG_LDFLAGS,
        _CS_XBS5_LPBIG_OFFBIG_LIBS,
        _CS_XBS5_LPBIG_OFFBIG_LINTFLAGS,

        _CS_POSIX_V6_ILP32_OFF32_CFLAGS,
        _CS_POSIX_V6_ILP32_OFF32_LDFLAGS,
        _CS_POSIX_V6_ILP32_OFF32_LIBS,
        _CS_POSIX_V6_ILP32_OFF32_LINTFLAGS,
        _CS_POSIX_V6_ILP32_OFFBIG_CFLAGS,
        _CS_POSIX_V6_ILP32_OFFBIG_LDFLAGS,
        _CS_POSIX_V6_ILP32_OFFBIG_LIBS,
        _CS_POSIX_V6_ILP32_OFFBIG_LINTFLAGS,
        _CS_POSIX_V6_LP64_OFF64_CFLAGS,
        _CS_POSIX_V6_LP64_OFF64_LDFLAGS,
        _CS_POSIX_V6_LP64_OFF64_LIBS,
        _CS_POSIX_V6_LP64_OFF64_LINTFLAGS,
        _CS_POSIX_V6_LPBIG_OFFBIG_CFLAGS,
        _CS_POSIX_V6_LPBIG_OFFBIG_LDFLAGS,
        _CS_POSIX_V6_LPBIG_OFFBIG_LIBS,
        _CS_POSIX_V6_LPBIG_OFFBIG_LINTFLAGS
    }

    enum
    {
        _PC_LINK_MAX,
        _PC_MAX_CANON,
        _PC_MAX_INPUT,
        _PC_NAME_MAX,
        _PC_PATH_MAX,
        _PC_PIPE_BUF,
        _PC_CHOWN_RESTRICTED,
        _PC_NO_TRUNC,
        _PC_VDISABLE,
        _PC_SYNC_IO,
        _PC_ASYNC_IO,
        _PC_PRIO_IO,
        _PC_SOCK_MAXBUF,
        _PC_FILESIZEBITS,
        _PC_REC_INCR_XFER_SIZE,
        _PC_REC_MAX_XFER_SIZE,
        _PC_REC_MIN_XFER_SIZE,
        _PC_REC_XFER_ALIGN,
        _PC_ALLOC_SIZE_MIN,
        _PC_SYMLINK_MAX,
        _PC_2_SYMLINKS
    }

    enum
    {
        _SC_ARG_MAX,
        _SC_CHILD_MAX,
        _SC_CLK_TCK,
        _SC_NGROUPS_MAX,
        _SC_OPEN_MAX,
        _SC_STREAM_MAX,
        _SC_TZNAME_MAX,
        _SC_JOB_CONTROL,
        _SC_SAVED_IDS,
        _SC_REALTIME_SIGNALS,
        _SC_PRIORITY_SCHEDULING,
        _SC_TIMERS,
        _SC_ASYNCHRONOUS_IO,
        _SC_PRIORITIZED_IO,
        _SC_SYNCHRONIZED_IO,
        _SC_FSYNC,
        _SC_MAPPED_FILES,
        _SC_MEMLOCK,
        _SC_MEMLOCK_RANGE,
        _SC_MEMORY_PROTECTION,
        _SC_MESSAGE_PASSING,
        _SC_SEMAPHORES,
        _SC_SHARED_MEMORY_OBJECTS,
        _SC_AIO_LISTIO_MAX,
        _SC_AIO_MAX,
        _SC_AIO_PRIO_DELTA_MAX,
        _SC_DELAYTIMER_MAX,
        _SC_MQ_OPEN_MAX,
        _SC_MQ_PRIO_MAX,
        _SC_VERSION,
        _SC_PAGESIZE,
        _SC_PAGE_SIZE = _SC_PAGESIZE,
        _SC_RTSIG_MAX,
        _SC_SEM_NSEMS_MAX,
        _SC_SEM_VALUE_MAX,
        _SC_SIGQUEUE_MAX,
        _SC_TIMER_MAX,

        _SC_BC_BASE_MAX,
        _SC_BC_DIM_MAX,
        _SC_BC_SCALE_MAX,
        _SC_BC_STRING_MAX,
        _SC_COLL_WEIGHTS_MAX,
        _SC_EQUIV_CLASS_MAX,
        _SC_EXPR_NEST_MAX,
        _SC_LINE_MAX,
        _SC_RE_DUP_MAX,
        _SC_CHARCLASS_NAME_MAX,

        _SC_2_VERSION,
        _SC_2_C_BIND,
        _SC_2_C_DEV,
        _SC_2_FORT_DEV,
        _SC_2_FORT_RUN,
        _SC_2_SW_DEV,
        _SC_2_LOCALEDEF,

        _SC_PII,
        _SC_PII_XTI,
        _SC_PII_SOCKET,
        _SC_PII_INTERNET,
        _SC_PII_OSI,
        _SC_POLL,
        _SC_SELECT,
        _SC_UIO_MAXIOV,
        _SC_IOV_MAX = _SC_UIO_MAXIOV,
        _SC_PII_INTERNET_STREAM,
        _SC_PII_INTERNET_DGRAM,
        _SC_PII_OSI_COTS,
        _SC_PII_OSI_CLTS,
        _SC_PII_OSI_M,
        _SC_T_IOV_MAX,

        _SC_THREADS,
        _SC_THREAD_SAFE_FUNCTIONS,
        _SC_GETGR_R_SIZE_MAX,
        _SC_GETPW_R_SIZE_MAX,
        _SC_LOGIN_NAME_MAX,
        _SC_TTY_NAME_MAX,
        _SC_THREAD_DESTRUCTOR_ITERATIONS,
        _SC_THREAD_KEYS_MAX,
        _SC_THREAD_STACK_MIN,
        _SC_THREAD_THREADS_MAX,
        _SC_THREAD_ATTR_STACKADDR,
        _SC_THREAD_ATTR_STACKSIZE,
        _SC_THREAD_PRIORITY_SCHEDULING,
        _SC_THREAD_PRIO_INHERIT,
        _SC_THREAD_PRIO_PROTECT,
        _SC_THREAD_PROCESS_SHARED,

        _SC_NPROCESSORS_CONF,
        _SC_NPROCESSORS_ONLN,
        _SC_PHYS_PAGES,
        _SC_AVPHYS_PAGES,
        _SC_ATEXIT_MAX,
        _SC_PASS_MAX,

        _SC_XOPEN_VERSION,
        _SC_XOPEN_XCU_VERSION,
        _SC_XOPEN_UNIX,
        _SC_XOPEN_CRYPT,
        _SC_XOPEN_ENH_I18N,
        _SC_XOPEN_SHM,

        _SC_2_CHAR_TERM,
        _SC_2_C_VERSION,
        _SC_2_UPE,

        _SC_XOPEN_XPG2,
        _SC_XOPEN_XPG3,
        _SC_XOPEN_XPG4,

        _SC_CHAR_BIT,
        _SC_CHAR_MAX,
        _SC_CHAR_MIN,
        _SC_INT_MAX,
        _SC_INT_MIN,
        _SC_LONG_BIT,
        _SC_WORD_BIT,
        _SC_MB_LEN_MAX,
        _SC_NZERO,
        _SC_SSIZE_MAX,
        _SC_SCHAR_MAX,
        _SC_SCHAR_MIN,
        _SC_SHRT_MAX,
        _SC_SHRT_MIN,
        _SC_UCHAR_MAX,
        _SC_UINT_MAX,
        _SC_ULONG_MAX,
        _SC_USHRT_MAX,

        _SC_NL_ARGMAX,
        _SC_NL_LANGMAX,
        _SC_NL_MSGMAX,
        _SC_NL_NMAX,
        _SC_NL_SETMAX,
        _SC_NL_TEXTMAX,

        _SC_XBS5_ILP32_OFF32,
        _SC_XBS5_ILP32_OFFBIG,
        _SC_XBS5_LP64_OFF64,
        _SC_XBS5_LPBIG_OFFBIG,

        _SC_XOPEN_LEGACY,
        _SC_XOPEN_REALTIME,
        _SC_XOPEN_REALTIME_THREADS,

        _SC_ADVISORY_INFO,
        _SC_BARRIERS,
        _SC_BASE,
        _SC_C_LANG_SUPPORT,
        _SC_C_LANG_SUPPORT_R,
        _SC_CLOCK_SELECTION,
        _SC_CPUTIME,
        _SC_THREAD_CPUTIME,
        _SC_DEVICE_IO,
        _SC_DEVICE_SPECIFIC,
        _SC_DEVICE_SPECIFIC_R,
        _SC_FD_MGMT,
        _SC_FIFO,
        _SC_PIPE,
        _SC_FILE_ATTRIBUTES,
        _SC_FILE_LOCKING,
        _SC_FILE_SYSTEM,
        _SC_MONOTONIC_CLOCK,
        _SC_MULTI_PROCESS,
        _SC_SINGLE_PROCESS,
        _SC_NETWORKING,
        _SC_READER_WRITER_LOCKS,
        _SC_SPIN_LOCKS,
        _SC_REGEXP,
        _SC_REGEX_VERSION,
        _SC_SHELL,
        _SC_SIGNALS,
        _SC_SPAWN,
        _SC_SPORADIC_SERVER,
        _SC_THREAD_SPORADIC_SERVER,
        _SC_SYSTEM_DATABASE,
        _SC_SYSTEM_DATABASE_R,
        _SC_TIMEOUTS,
        _SC_TYPED_MEMORY_OBJECTS,
        _SC_USER_GROUPS,
        _SC_USER_GROUPS_R,
        _SC_2_PBS,
        _SC_2_PBS_ACCOUNTING,
        _SC_2_PBS_LOCATE,
        _SC_2_PBS_MESSAGE,
        _SC_2_PBS_TRACK,
        _SC_SYMLOOP_MAX,
        _SC_STREAMS,
        _SC_2_PBS_CHECKPOINT,

        _SC_V6_ILP32_OFF32,
        _SC_V6_ILP32_OFFBIG,
        _SC_V6_LP64_OFF64,
        _SC_V6_LPBIG_OFFBIG,

        _SC_HOST_NAME_MAX,
        _SC_TRACE,
        _SC_TRACE_EVENT_FILTER,
        _SC_TRACE_INHERIT,
        _SC_TRACE_LOG,

        _SC_LEVEL1_ICACHE_SIZE,
        _SC_LEVEL1_ICACHE_ASSOC,
        _SC_LEVEL1_ICACHE_LINESIZE,
        _SC_LEVEL1_DCACHE_SIZE,
        _SC_LEVEL1_DCACHE_ASSOC,
        _SC_LEVEL1_DCACHE_LINESIZE,
        _SC_LEVEL2_CACHE_SIZE,
        _SC_LEVEL2_CACHE_ASSOC,
        _SC_LEVEL2_CACHE_LINESIZE,
        _SC_LEVEL3_CACHE_SIZE,
        _SC_LEVEL3_CACHE_ASSOC,
        _SC_LEVEL3_CACHE_LINESIZE,
        _SC_LEVEL4_CACHE_SIZE,
        _SC_LEVEL4_CACHE_ASSOC,
        _SC_LEVEL4_CACHE_LINESIZE,

        _SC_IPV6 = _SC_LEVEL1_ICACHE_SIZE + 50,
        _SC_RAW_SOCKETS
    }

} else version (OSX) {

    enum F_OK       = 0;
    enum R_OK       = 4;
    enum W_OK       = 2;
    enum X_OK       = 1;

    enum F_ULOCK    = 0;
    enum F_LOCK     = 1;
    enum F_TLOCK    = 2;
    enum F_TEST     = 3;

    enum
    {
        _SC_ARG_MAX                      =   1,
        _SC_CHILD_MAX                    =   2,
        _SC_CLK_TCK                      =   3,
        _SC_NGROUPS_MAX                  =   4,
        _SC_OPEN_MAX                     =   5,
        _SC_JOB_CONTROL                  =   6,
        _SC_SAVED_IDS                    =   7,
        _SC_VERSION                      =   8,
        _SC_BC_BASE_MAX                  =   9,
        _SC_BC_DIM_MAX                   =  10,
        _SC_BC_SCALE_MAX                 =  11,
        _SC_BC_STRING_MAX                =  12,
        _SC_COLL_WEIGHTS_MAX             =  13,
        _SC_EXPR_NEST_MAX                =  14,
        _SC_LINE_MAX                     =  15,
        _SC_RE_DUP_MAX                   =  16,
        _SC_2_VERSION                    =  17,
        _SC_2_C_BIND                     =  18,
        _SC_2_C_DEV                      =  19,
        _SC_2_CHAR_TERM                  =  20,
        _SC_2_FORT_DEV                   =  21,
        _SC_2_FORT_RUN                   =  22,
        _SC_2_LOCALEDEF                  =  23,
        _SC_2_SW_DEV                     =  24,
        _SC_2_UPE                        =  25,
        _SC_STREAM_MAX                   =  26,
        _SC_TZNAME_MAX                   =  27,
        _SC_ASYNCHRONOUS_IO              =  28,
        _SC_PAGESIZE                     =  29,
        _SC_MEMLOCK                      =  30,
        _SC_MEMLOCK_RANGE                =  31,
        _SC_MEMORY_PROTECTION            =  32,
        _SC_MESSAGE_PASSING              =  33,
        _SC_PRIORITIZED_IO               =  34,
        _SC_PRIORITY_SCHEDULING          =  35,
        _SC_REALTIME_SIGNALS             =  36,
        _SC_SEMAPHORES                   =  37,
        _SC_FSYNC                        =  38,
        _SC_SHARED_MEMORY_OBJECTS        =  39,
        _SC_SYNCHRONIZED_IO              =  40,
        _SC_TIMERS                       =  41,
        _SC_AIO_LISTIO_MAX               =  42,
        _SC_AIO_MAX                      =  43,
        _SC_AIO_PRIO_DELTA_MAX           =  44,
        _SC_DELAYTIMER_MAX               =  45,
        _SC_MQ_OPEN_MAX                  =  46,
        _SC_MAPPED_FILES                 =  47,
        _SC_RTSIG_MAX                    =  48,
        _SC_SEM_NSEMS_MAX                =  49,
        _SC_SEM_VALUE_MAX                =  50,
        _SC_SIGQUEUE_MAX                 =  51,
        _SC_TIMER_MAX                    =  52,
        _SC_IOV_MAX                      =  56,
        _SC_NPROCESSORS_CONF             =  57,
        _SC_NPROCESSORS_ONLN             =  58,
        _SC_2_PBS                        =  59,
        _SC_2_PBS_ACCOUNTING             =  60,
        _SC_2_PBS_CHECKPOINT             =  61,
        _SC_2_PBS_LOCATE                 =  62,
        _SC_2_PBS_MESSAGE                =  63,
        _SC_2_PBS_TRACK                  =  64,
        _SC_ADVISORY_INFO                =  65,
        _SC_BARRIERS                     =  66,
        _SC_CLOCK_SELECTION              =  67,
        _SC_CPUTIME                      =  68,
        _SC_FILE_LOCKING                 =  69,
        _SC_GETGR_R_SIZE_MAX             =  70,
        _SC_GETPW_R_SIZE_MAX             =  71,
        _SC_HOST_NAME_MAX                =  72,
        _SC_LOGIN_NAME_MAX               =  73,
        _SC_MONOTONIC_CLOCK              =  74,
        _SC_MQ_PRIO_MAX                  =  75,
        _SC_READER_WRITER_LOCKS          =  76,
        _SC_REGEXP                       =  77,
        _SC_SHELL                        =  78,
        _SC_SPAWN                        =  79,
        _SC_SPIN_LOCKS                   =  80,
        _SC_SPORADIC_SERVER              =  81,
        _SC_THREAD_ATTR_STACKADDR        =  82,
        _SC_THREAD_ATTR_STACKSIZE        =  83,
        _SC_THREAD_CPUTIME               =  84,
        _SC_THREAD_DESTRUCTOR_ITERATIONS =  85,
        _SC_THREAD_KEYS_MAX              =  86,
        _SC_THREAD_PRIO_INHERIT          =  87,
        _SC_THREAD_PRIO_PROTECT          =  88,
        _SC_THREAD_PRIORITY_SCHEDULING   =  89,
        _SC_THREAD_PROCESS_SHARED        =  90,
        _SC_THREAD_SAFE_FUNCTIONS        =  91,
        _SC_THREAD_SPORADIC_SERVER       =  92,
        _SC_THREAD_STACK_MIN             =  93,
        _SC_THREAD_THREADS_MAX           =  94,
        _SC_TIMEOUTS                     =  95,
        _SC_THREADS                      =  96,
        _SC_TRACE                        =  97,
        _SC_TRACE_EVENT_FILTER           =  98,
        _SC_TRACE_INHERIT                =  99,
        _SC_TRACE_LOG                    = 100,
        _SC_TTY_NAME_MAX                 = 101,
        _SC_TYPED_MEMORY_OBJECTS         = 102,
        _SC_V6_ILP32_OFF32               = 103,
        _SC_V6_ILP32_OFFBIG              = 104,
        _SC_V6_LP64_OFF64                = 105,
        _SC_V6_LPBIG_OFFBIG              = 106,
        _SC_ATEXIT_MAX                   = 107,
        _SC_XOPEN_CRYPT                  = 108,
        _SC_XOPEN_ENH_I18N               = 109,
        _SC_XOPEN_LEGACY                 = 110,
        _SC_XOPEN_REALTIME               = 111,
        _SC_XOPEN_REALTIME_THREADS       = 112,
        _SC_XOPEN_SHM                    = 113,
        _SC_XOPEN_STREAMS                = 114,
        _SC_XOPEN_UNIX                   = 115,
        _SC_XOPEN_VERSION                = 116,
        _SC_IPV6                         = 118,
        _SC_RAW_SOCKETS                  = 119,
        _SC_SYMLOOP_MAX                  = 120,
        _SC_XOPEN_XCU_VERSION            = 121,
        _SC_XBS5_ILP32_OFF32             = 122,
        _SC_XBS5_ILP32_OFFBIG            = 123,
        _SC_XBS5_LP64_OFF64              = 124,
        _SC_XBS5_LPBIG_OFFBIG            = 125,
        _SC_SS_REPL_MAX                  = 126,
        _SC_TRACE_EVENT_NAME_MAX         = 127,
        _SC_TRACE_NAME_MAX               = 128,
        _SC_TRACE_SYS_MAX                = 129,
        _SC_TRACE_USER_EVENT_MAX         = 130,
        _SC_PASS_MAX                     = 131,
    }

    enum _SC_PAGE_SIZE = _SC_PAGESIZE;

    enum
    {
        _CS_PATH                                =     1,
        _CS_POSIX_V6_ILP32_OFF32_CFLAGS         =     2,
        _CS_POSIX_V6_ILP32_OFF32_LDFLAGS        =     3,
        _CS_POSIX_V6_ILP32_OFF32_LIBS           =     4,
        _CS_POSIX_V6_ILP32_OFFBIG_CFLAGS        =     5,
        _CS_POSIX_V6_ILP32_OFFBIG_LDFLAGS       =     6,
        _CS_POSIX_V6_ILP32_OFFBIG_LIBS          =     7,
        _CS_POSIX_V6_LP64_OFF64_CFLAGS          =     8,
        _CS_POSIX_V6_LP64_OFF64_LDFLAGS         =     9,
        _CS_POSIX_V6_LP64_OFF64_LIBS            =    10,
        _CS_POSIX_V6_LPBIG_OFFBIG_CFLAGS        =    11,
        _CS_POSIX_V6_LPBIG_OFFBIG_LDFLAGS       =    12,
        _CS_POSIX_V6_LPBIG_OFFBIG_LIBS          =    13,
        _CS_POSIX_V6_WIDTH_RESTRICTED_ENVS      =    14,

        _CS_XBS5_ILP32_OFF32_CFLAGS             =    20,
        _CS_XBS5_ILP32_OFF32_LDFLAGS            =    21,
        _CS_XBS5_ILP32_OFF32_LIBS               =    22,
        _CS_XBS5_ILP32_OFF32_LINTFLAGS          =    23,
        _CS_XBS5_ILP32_OFFBIG_CFLAGS            =    24,
        _CS_XBS5_ILP32_OFFBIG_LDFLAGS           =    25,
        _CS_XBS5_ILP32_OFFBIG_LIBS              =    26,
        _CS_XBS5_ILP32_OFFBIG_LINTFLAGS         =    27,
        _CS_XBS5_LP64_OFF64_CFLAGS              =    28,
        _CS_XBS5_LP64_OFF64_LDFLAGS             =    29,
        _CS_XBS5_LP64_OFF64_LIBS                =    30,
        _CS_XBS5_LP64_OFF64_LINTFLAGS           =    31,
        _CS_XBS5_LPBIG_OFFBIG_CFLAGS            =    32,
        _CS_XBS5_LPBIG_OFFBIG_LDFLAGS           =    33,
        _CS_XBS5_LPBIG_OFFBIG_LIBS              =    34,
        _CS_XBS5_LPBIG_OFFBIG_LINTFLAGS         =    35,

        _CS_DARWIN_USER_DIR                     = 65536,
        _CS_DARWIN_USER_TEMP_DIR                = 65537,
        _CS_DARWIN_USER_CACHE_DIR               = 65538,
    }

} else version (FreeBSD) {

    enum F_OK       = 0;
    enum R_OK       = 0x04;
    enum W_OK       = 0x02;
    enum X_OK       = 0x01;

    enum F_ULOCK    = 0;
    enum F_LOCK     = 1;
    enum F_TLOCK    = 2;
    enum F_TEST     = 3;

    enum
    {
        _SC_ARG_MAX                        =   1,
        _SC_CHILD_MAX                      =   2,
        _SC_CLK_TCK                        =   3,
        _SC_NGROUPS_MAX                    =   4,
        _SC_OPEN_MAX                       =   5,
        _SC_JOB_CONTROL                    =   6,
        _SC_SAVED_IDS                      =   7,
        _SC_VERSION                        =   8,
        _SC_BC_BASE_MAX                    =   9,
        _SC_BC_DIM_MAX                     =  10,
        _SC_BC_SCALE_MAX                   =  11,
        _SC_BC_STRING_MAX                  =  12,
        _SC_COLL_WEIGHTS_MAX               =  13,
        _SC_EXPR_NEST_MAX                  =  14,
        _SC_LINE_MAX                       =  15,
        _SC_RE_DUP_MAX                     =  16,
        _SC_2_VERSION                      =  17,
        _SC_2_C_BIND                       =  18,
        _SC_2_C_DEV                        =  19,
        _SC_2_CHAR_TERM                    =  20,
        _SC_2_FORT_DEV                     =  21,
        _SC_2_FORT_RUN                     =  22,
        _SC_2_LOCALEDEF                    =  23,
        _SC_2_SW_DEV                       =  24,
        _SC_2_UPE                          =  25,
        _SC_STREAM_MAX                     =  26,
        _SC_TZNAME_MAX                     =  27,
        _SC_ASYNCHRONOUS_IO                =  28,
        _SC_MAPPED_FILES                   =  29,
        _SC_MEMLOCK                        =  30,
        _SC_MEMLOCK_RANGE                  =  31,
        _SC_MEMORY_PROTECTION              =  32,
        _SC_MESSAGE_PASSING                =  33,
        _SC_PRIORITIZED_IO                 =  34,
        _SC_PRIORITY_SCHEDULING            =  35,
        _SC_REALTIME_SIGNALS               =  36,
        _SC_SEMAPHORES                     =  37,
        _SC_FSYNC                          =  38,
        _SC_SHARED_MEMORY_OBJECTS          =  39,
        _SC_SYNCHRONIZED_IO                =  40,
        _SC_TIMERS                         =  41,
        _SC_AIO_LISTIO_MAX                 =  42,
        _SC_AIO_MAX                        =  43,
        _SC_AIO_PRIO_DELTA_MAX             =  44,
        _SC_DELAYTIMER_MAX                 =  45,
        _SC_MQ_OPEN_MAX                    =  46,
        _SC_PAGESIZE                       =  47,
        _SC_RTSIG_MAX                      =  48,
        _SC_SEM_NSEMS_MAX                  =  49,
        _SC_SEM_VALUE_MAX                  =  50,
        _SC_SIGQUEUE_MAX                   =  51,
        _SC_TIMER_MAX                      =  52,
        _SC_IOV_MAX                        =  56,
        _SC_NPROCESSORS_CONF               =  57,
        _SC_NPROCESSORS_ONLN               =  58,
        _SC_2_PBS                          =  59,
        _SC_2_PBS_ACCOUNTING               =  60,
        _SC_2_PBS_CHECKPOINT               =  61,
        _SC_2_PBS_LOCATE                   =  62,
        _SC_2_PBS_MESSAGE                  =  63,
        _SC_2_PBS_TRACK                    =  64,
        _SC_ADVISORY_INFO                  =  65,
        _SC_BARRIERS                       =  66,
        _SC_CLOCK_SELECTION                =  67,
        _SC_CPUTIME                        =  68,
        _SC_FILE_LOCKING                   =  69,
        _SC_GETGR_R_SIZE_MAX               =  70,
        _SC_GETPW_R_SIZE_MAX               =  71,
        _SC_HOST_NAME_MAX                  =  72,
        _SC_LOGIN_NAME_MAX                 =  73,
        _SC_MONOTONIC_CLOCK                =  74,
        _SC_MQ_PRIO_MAX                    =  75,
        _SC_READER_WRITER_LOCKS            =  76,
        _SC_REGEXP                         =  77,
        _SC_SHELL                          =  78,
        _SC_SPAWN                          =  79,
        _SC_SPIN_LOCKS                     =  80,
        _SC_SPORADIC_SERVER                =  81,
        _SC_THREAD_ATTR_STACKADDR          =  82,
        _SC_THREAD_ATTR_STACKSIZE          =  83,
        _SC_THREAD_CPUTIME                 =  84,
        _SC_THREAD_DESTRUCTOR_ITERATIONS   =  85,
        _SC_THREAD_KEYS_MAX                =  86,
        _SC_THREAD_PRIO_INHERIT            =  87,
        _SC_THREAD_PRIO_PROTECT            =  88,
        _SC_THREAD_PRIORITY_SCHEDULING     =  89,
        _SC_THREAD_PROCESS_SHARED          =  90,
        _SC_THREAD_SAFE_FUNCTIONS          =  91,
        _SC_THREAD_SPORADIC_SERVER         =  92,
        _SC_THREAD_STACK_MIN               =  93,
        _SC_THREAD_THREADS_MAX             =  94,
        _SC_TIMEOUTS                       =  95,
        _SC_THREADS                        =  96,
        _SC_TRACE                          =  97,
        _SC_TRACE_EVENT_FILTER             =  98,
        _SC_TRACE_INHERIT                  =  99,
        _SC_TRACE_LOG                      = 100,
        _SC_TTY_NAME_MAX                   = 101,
        _SC_TYPED_MEMORY_OBJECTS           = 102,
        _SC_V6_ILP32_OFF32                 = 103,
        _SC_V6_ILP32_OFFBIG                = 104,
        _SC_V6_LP64_OFF64                  = 105,
        _SC_V6_LPBIG_OFFBIG                = 106,
        _SC_IPV6                           = 118,
        _SC_RAW_SOCKETS                    = 119,
        _SC_SYMLOOP_MAX                    = 120,
        _SC_ATEXIT_MAX                     = 107,
        _SC_XOPEN_CRYPT                    = 108,
        _SC_XOPEN_ENH_I18N                 = 109,
        _SC_XOPEN_LEGACY                   = 110,
        _SC_XOPEN_REALTIME                 = 111,
        _SC_XOPEN_REALTIME_THREADS         = 112,
        _SC_XOPEN_SHM                      = 113,
        _SC_XOPEN_STREAMS                  = 114,
        _SC_XOPEN_UNIX                     = 115,
        _SC_XOPEN_VERSION                  = 116,
        _SC_XOPEN_XCU_VERSION              = 117,
        _SC_CPUSET_SIZE                    = 122,
        _SC_PHYS_PAGES                     = 121,
    }

    enum _SC_PAGE_SIZE = _SC_PAGESIZE;

    enum
    {
        _CS_PATH                           =   1,
        _CS_POSIX_V6_ILP32_OFF32_CFLAGS    =   2,
        _CS_POSIX_V6_ILP32_OFF32_LDFLAGS   =   3,
        _CS_POSIX_V6_ILP32_OFF32_LIBS      =   4,
        _CS_POSIX_V6_ILP32_OFFBIG_CFLAGS   =   5,
        _CS_POSIX_V6_ILP32_OFFBIG_LDFLAGS  =   6,
        _CS_POSIX_V6_ILP32_OFFBIG_LIBS     =   7,
        _CS_POSIX_V6_LP64_OFF64_CFLAGS     =   8,
        _CS_POSIX_V6_LP64_OFF64_LDFLAGS    =   9,
        _CS_POSIX_V6_LP64_OFF64_LIBS       =  10,
        _CS_POSIX_V6_LPBIG_OFFBIG_CFLAGS   =  11,
        _CS_POSIX_V6_LPBIG_OFFBIG_LDFLAGS  =  12,
        _CS_POSIX_V6_LPBIG_OFFBIG_LIBS     =  13,
        _CS_POSIX_V6_WIDTH_RESTRICTED_ENVS =  14,
    }

} else version (CRuntime_Bionic) {

    enum F_OK       = 0;
    enum R_OK       = 4;
    enum W_OK       = 2;
    enum X_OK       = 1;

    enum _SC_PAGESIZE         = 0x0027;
    enum _SC_NPROCESSORS_ONLN = 0x0061;
    enum _SC_THREAD_STACK_MIN = 0x004c;

} else version (Solaris) {

    enum F_OK       = 0;
    enum R_OK       = 4;
    enum W_OK       = 2;
    enum X_OK       = 1;

    enum F_ULOCK    = 0;
    enum F_LOCK     = 1;
    enum F_TLOCK    = 2;
    enum F_TEST     = 3;

    enum
    {
        // large file compilation environment configuration
        _CS_LFS_CFLAGS                  = 68,
        _CS_LFS_LDFLAGS                 = 69,
        _CS_LFS_LIBS                    = 70,
        _CS_LFS_LINTFLAGS               = 71,
        // transitional large file interface configuration
        _CS_LFS64_CFLAGS                = 72,
        _CS_LFS64_LDFLAGS               = 73,
        _CS_LFS64_LIBS                  = 74,
        _CS_LFS64_LINTFLAGS             = 75,

        // UNIX 98
        _CS_XBS5_ILP32_OFF32_CFLAGS     = 700,
        _CS_XBS5_ILP32_OFF32_LDFLAGS    = 701,
        _CS_XBS5_ILP32_OFF32_LIBS       = 702,
        _CS_XBS5_ILP32_OFF32_LINTFLAGS  = 703,
        _CS_XBS5_ILP32_OFFBIG_CFLAGS    = 705,
        _CS_XBS5_ILP32_OFFBIG_LDFLAGS   = 706,
        _CS_XBS5_ILP32_OFFBIG_LIBS      = 707,
        _CS_XBS5_ILP32_OFFBIG_LINTFLAGS = 708,
        _CS_XBS5_LP64_OFF64_CFLAGS      = 709,
        _CS_XBS5_LP64_OFF64_LDFLAGS     = 710,
        _CS_XBS5_LP64_OFF64_LIBS        = 711,
        _CS_XBS5_LP64_OFF64_LINTFLAGS   = 712,
        _CS_XBS5_LPBIG_OFFBIG_CFLAGS    = 713,
        _CS_XBS5_LPBIG_OFFBIG_LDFLAGS   = 714,
        _CS_XBS5_LPBIG_OFFBIG_LIBS      = 715,
        _CS_XBS5_LPBIG_OFFBIG_LINTFLAGS = 716,

        // UNIX 03
        _CS_POSIX_V6_ILP32_OFF32_CFLAGS         = 800,
        _CS_POSIX_V6_ILP32_OFF32_LDFLAGS        = 801,
        _CS_POSIX_V6_ILP32_OFF32_LIBS           = 802,
        _CS_POSIX_V6_ILP32_OFF32_LINTFLAGS      = 803,
        _CS_POSIX_V6_ILP32_OFFBIG_CFLAGS        = 804,
        _CS_POSIX_V6_ILP32_OFFBIG_LDFLAGS       = 805,
        _CS_POSIX_V6_ILP32_OFFBIG_LIBS          = 806,
        _CS_POSIX_V6_ILP32_OFFBIG_LINTFLAGS     = 807,
        _CS_POSIX_V6_LP64_OFF64_CFLAGS          = 808,
        _CS_POSIX_V6_LP64_OFF64_LDFLAGS         = 809,
        _CS_POSIX_V6_LP64_OFF64_LIBS            = 810,
        _CS_POSIX_V6_LP64_OFF64_LINTFLAGS       = 811,
        _CS_POSIX_V6_LPBIG_OFFBIG_CFLAGS        = 812,
        _CS_POSIX_V6_LPBIG_OFFBIG_LDFLAGS       = 813,
        _CS_POSIX_V6_LPBIG_OFFBIG_LIBS          = 814,
        _CS_POSIX_V6_LPBIG_OFFBIG_LINTFLAGS     = 815,
        _CS_POSIX_V6_WIDTH_RESTRICTED_ENVS      = 816
    }

    enum {
        _SC_ARG_MAX                     = 1,
        _SC_CHILD_MAX                   = 2,
        _SC_CLK_TCK                     = 3,
        _SC_NGROUPS_MAX                 = 4,
        _SC_OPEN_MAX                    = 5,
        _SC_JOB_CONTROL                 = 6,
        _SC_SAVED_IDS                   = 7,
        _SC_VERSION                     = 8,

        _SC_PASS_MAX                    = 9,
        _SC_LOGNAME_MAX                 = 10,
        _SC_PAGESIZE                    = 11,
        _SC_XOPEN_VERSION               = 12,
        // 13 reserved for SVr4-ES/MP _SC_NACLS_MAX
        _SC_NPROCESSORS_CONF            = 14,
        _SC_NPROCESSORS_ONLN            = 15,
        _SC_STREAM_MAX                  = 16,
        _SC_TZNAME_MAX                  = 17,

        _SC_AIO_LISTIO_MAX              = 18,
        _SC_AIO_MAX                     = 19,
        _SC_AIO_PRIO_DELTA_MAX          = 20,
        _SC_ASYNCHRONOUS_IO             = 21,
        _SC_DELAYTIMER_MAX              = 22,
        _SC_FSYNC                       = 23,
        _SC_MAPPED_FILES                = 24,
        _SC_MEMLOCK                     = 25,
        _SC_MEMLOCK_RANGE               = 26,
        _SC_MEMORY_PROTECTION           = 27,
        _SC_MESSAGE_PASSING             = 28,
        _SC_MQ_OPEN_MAX                 = 29,
        _SC_MQ_PRIO_MAX                 = 30,
        _SC_PRIORITIZED_IO              = 31,
        _SC_PRIORITY_SCHEDULING         = 32,
        _SC_REALTIME_SIGNALS            = 33,
        _SC_RTSIG_MAX                   = 34,
        _SC_SEMAPHORES                  = 35,
        _SC_SEM_NSEMS_MAX               = 36,
        _SC_SEM_VALUE_MAX               = 37,
        _SC_SHARED_MEMORY_OBJECTS       = 38,
        _SC_SIGQUEUE_MAX                = 39,
        _SC_SIGRT_MIN                   = 40,
        _SC_SIGRT_MAX                   = 41,
        _SC_SYNCHRONIZED_IO             = 42,
        _SC_TIMERS                      = 43,
        _SC_TIMER_MAX                   = 44,

        _SC_2_C_BIND                    = 45,
        _SC_2_C_DEV                     = 46,
        _SC_2_C_VERSION                 = 47,
        _SC_2_FORT_DEV                  = 48,
        _SC_2_FORT_RUN                  = 49,
        _SC_2_LOCALEDEF                 = 50,
        _SC_2_SW_DEV                    = 51,
        _SC_2_UPE                       = 52,
        _SC_2_VERSION                   = 53,
        _SC_BC_BASE_MAX                 = 54,
        _SC_BC_DIM_MAX                  = 55,
        _SC_BC_SCALE_MAX                = 56,
        _SC_BC_STRING_MAX               = 57,
        _SC_COLL_WEIGHTS_MAX            = 58,
        _SC_EXPR_NEST_MAX               = 59,
        _SC_LINE_MAX                    = 60,
        _SC_RE_DUP_MAX                  = 61,
        _SC_XOPEN_CRYPT                 = 62,
        _SC_XOPEN_ENH_I18N              = 63,
        _SC_XOPEN_SHM                   = 64,
        _SC_2_CHAR_TERM                 = 66,
        _SC_XOPEN_XCU_VERSION           = 67,

        _SC_ATEXIT_MAX                  = 76,
        _SC_IOV_MAX                     = 77,
        _SC_XOPEN_UNIX                  = 78,

        _SC_T_IOV_MAX                   = 79,

        _SC_PHYS_PAGES                  = 500,
        _SC_AVPHYS_PAGES                = 501,

        _SC_COHER_BLKSZ         = 503,
        _SC_SPLIT_CACHE         = 504,
        _SC_ICACHE_SZ           = 505,
        _SC_DCACHE_SZ           = 506,
        _SC_ICACHE_LINESZ       = 507,
        _SC_DCACHE_LINESZ       = 508,
        _SC_ICACHE_BLKSZ        = 509,
        _SC_DCACHE_BLKSZ        = 510,
        _SC_DCACHE_TBLKSZ       = 511,
        _SC_ICACHE_ASSOC        = 512,
        _SC_DCACHE_ASSOC        = 513,

        _SC_MAXPID              = 514,
        _SC_STACK_PROT          = 515,
        _SC_NPROCESSORS_MAX     = 516,
        _SC_CPUID_MAX           = 517,
        _SC_EPHID_MAX           = 518,

        _SC_THREAD_DESTRUCTOR_ITERATIONS = 568,
        _SC_GETGR_R_SIZE_MAX            = 569,
        _SC_GETPW_R_SIZE_MAX            = 570,
        _SC_LOGIN_NAME_MAX              = 571,
        _SC_THREAD_KEYS_MAX             = 572,
        _SC_THREAD_STACK_MIN            = 573,
        _SC_THREAD_THREADS_MAX          = 574,
        _SC_TTY_NAME_MAX                = 575,
        _SC_THREADS                     = 576,
        _SC_THREAD_ATTR_STACKADDR       = 577,
        _SC_THREAD_ATTR_STACKSIZE       = 578,
        _SC_THREAD_PRIORITY_SCHEDULING  = 579,
        _SC_THREAD_PRIO_INHERIT         = 580,
        _SC_THREAD_PRIO_PROTECT         = 581,
        _SC_THREAD_PROCESS_SHARED       = 582,
        _SC_THREAD_SAFE_FUNCTIONS       = 583,

        _SC_XOPEN_LEGACY                = 717,
        _SC_XOPEN_REALTIME              = 718,
        _SC_XOPEN_REALTIME_THREADS      = 719,
        _SC_XBS5_ILP32_OFF32            = 720,
        _SC_XBS5_ILP32_OFFBIG           = 721,
        _SC_XBS5_LP64_OFF64             = 722,
        _SC_XBS5_LPBIG_OFFBIG           = 723,

        _SC_2_PBS                       = 724,
        _SC_2_PBS_ACCOUNTING            = 725,
        _SC_2_PBS_CHECKPOINT            = 726,
        _SC_2_PBS_LOCATE                = 728,
        _SC_2_PBS_MESSAGE               = 729,
        _SC_2_PBS_TRACK                 = 730,
        _SC_ADVISORY_INFO               = 731,
        _SC_BARRIERS                    = 732,
        _SC_CLOCK_SELECTION             = 733,
        _SC_CPUTIME                     = 734,
        _SC_HOST_NAME_MAX               = 735,
        _SC_MONOTONIC_CLOCK             = 736,
        _SC_READER_WRITER_LOCKS         = 737,
        _SC_REGEXP                      = 738,
        _SC_SHELL                       = 739,
        _SC_SPAWN                       = 740,
        _SC_SPIN_LOCKS                  = 741,
        _SC_SPORADIC_SERVER             = 742,
        _SC_SS_REPL_MAX                 = 743,
        _SC_SYMLOOP_MAX                 = 744,
        _SC_THREAD_CPUTIME              = 745,
        _SC_THREAD_SPORADIC_SERVER      = 746,
        _SC_TIMEOUTS                    = 747,
        _SC_TRACE                       = 748,
        _SC_TRACE_EVENT_FILTER          = 749,
        _SC_TRACE_EVENT_NAME_MAX        = 750,
        _SC_TRACE_INHERIT               = 751,
        _SC_TRACE_LOG                   = 752,
        _SC_TRACE_NAME_MAX              = 753,
        _SC_TRACE_SYS_MAX               = 754,
        _SC_TRACE_USER_EVENT_MAX        = 755,
        _SC_TYPED_MEMORY_OBJECTS        = 756,
        _SC_V6_ILP32_OFF32              = 757,
        _SC_V6_ILP32_OFFBIG             = 758,
        _SC_V6_LP64_OFF64               = 759,
        _SC_V6_LPBIG_OFFBIG             = 760,
        _SC_XOPEN_STREAMS               = 761,
        _SC_IPV6                        = 762,
        _SC_RAW_SOCKETS                 = 763,
    }
    enum _SC_PAGE_SIZE = _SC_PAGESIZE;

    enum {
        _PC_LINK_MAX            = 1,
        _PC_MAX_CANON           = 2,
        _PC_MAX_INPUT           = 3,
        _PC_NAME_MAX            = 4,
        _PC_PATH_MAX            = 5,
        _PC_PIPE_BUF            = 6,
        _PC_NO_TRUNC            = 7,
        _PC_VDISABLE            = 8,
        _PC_CHOWN_RESTRICTED    = 9,

        _PC_ASYNC_IO            = 10,
        _PC_PRIO_IO             = 11,
        _PC_SYNC_IO             = 12,

        _PC_ALLOC_SIZE_MIN      = 13,
        _PC_REC_INCR_XFER_SIZE  = 14,
        _PC_REC_MAX_XFER_SIZE   = 15,
        _PC_REC_MIN_XFER_SIZE   = 16,
        _PC_REC_XFER_ALIGN      = 17,
        _PC_SYMLINK_MAX         = 18,
        _PC_2_SYMLINKS          = 19,
        _PC_ACL_ENABLED         = 20,
        _PC_MIN_HOLE_SIZE       = 21,
        _PC_CASE_BEHAVIOR       = 22,
        _PC_SATTR_ENABLED       = 23,
        _PC_SATTR_EXISTS        = 24,
        _PC_ACCESS_FILTERING    = 25,

        _PC_TIMESTAMP_RESOLUTION = 26,

        _PC_FILESIZEBITS        = 67,

        _PC_XATTR_ENABLED       = 100,
        _PC_XATTR_EXISTS        = 101
    }

    enum _PC_LAST = 101;
}

//
// File Synchronization (FSC)
//
/*
int fsync(int);
*/

version (Linux) {

	fn fsync(i32) i32;

} else version (OSX) {

	fn fsync(i32) i32;

}

//
// Synchronized I/O (SIO)
//
/*
int fdatasync(int);
*/

version (Linux) {

	fn fdatasync(i32) i32;

}

//
// XOpen (XSI)
//
/*
char*      crypt(in char*, in char*);
char*      ctermid(char*);
void       encrypt(ref char[64], int);
int        fchdir(int);
c_long     gethostid();
pid_t      getpgid(pid_t);
pid_t      getsid(pid_t);
char*      getwd(char*); // LEGACY
int        lchown(in char*, uid_t, gid_t);
int        lockf(int, int, off_t);
int        nice(int);
ssize_t    pread(int, void*, size_t, off_t);
ssize_t    pwrite(int, in void*, size_t, off_t);
pid_t      setpgrp();
int        setregid(gid_t, gid_t);
int        setreuid(uid_t, uid_t);
void       swab(in void*, void*, ssize_t);
void       sync();
int        truncate(in char*, off_t);
useconds_t ualarm(useconds_t, useconds_t);
int        usleep(useconds_t);
pid_t      vfork();
*/

version (Linux) {

	fn crypt(in char*, in char*) char*;
	fn ctermid(char*) char*;
	fn encrypt(ref char[64], i32);
	fn fchdir(i32) i32;
	fn gethostid() c_long;
	fn getpgid(pid_t) pid_t;
	fn getsid(pid_t) pid_t;
	fn getwd(char*) char*;
	fn lchown(in char*, uid_t, gid_t) i32;
    //int        lockf(int, int, off_t);
	fn nice(i32) i32;
    //ssize_t    pread(int, void*, size_t, off_t);
    //ssize_t    pwrite(int, in void*, size_t, off_t);
	fn setpgrp() pid_t;
	fn setregid(gid_t, gid_t) i32;
	fn setreuid(uid_t, uid_t) i32;
	fn swab(in void*, void*, ssize_t);
	fn sync();
    //int        truncate(in char*, off_t);
	fn ualarm(useconds_t, useconds_t) useconds_t;
	fn usleep(useconds_t) i32;
	fn vfork() pid_t;

//  static if( __USE_FILE_OFFSET64 )
//  {
//    int        lockf64(int, int, off_t) /*@trusted*/;
//    alias      lockf64 lockf;

//    ssize_t    pread64(int, void*, size_t, off_t);
//    alias      pread64 pread;

//    ssize_t    pwrite64(int, in void*, size_t, off_t);
//    alias      pwrite64 pwrite;

//    int        truncate64(in char*, off_t);
//    alias      truncate64 truncate;
//  }
//  else
//  {
	fn lockf(i32, i32, off_t) i32;
	fn pread(i32, void*, size_t, off_t) ssize_t;
	fn pwrite(i32, in void*, size_t, off_t) ssize_t;
	fn truncate(in char*, off_t) i32;
//  }

} else version (OSX) {

	fn crypt(in char*, in char*) char*;
	fn ctermid(char*) char*;
	fn encrypt(ref char[64], i32);
	fn fchdir(i32) i32;
	fn gethostid() c_long;
	fn getpgid(pid_t) pid_t;
	fn getsid(pid_t) pid_t;
	fn getwd(char*) char*;
	fn lchown(in char*, uid_t, gid_t);
	fn lockf(i32, i32, off_t) i32;
	fn nice(i32) i32;
	fn pread(i32, void*, size_t, off_t) ssize_t;
	fn pwrite(i32, in void*, size_t, off_t) ssize_t;
	fn setpgrp() pid_t;
	fn setregid(gid_t, gid_t) i32;
	fn setreuid(uid_t, uid_t) i32;
	fn swab(in void*, void*, ssize_t);
	fn sync();
	fn truncate(in char*, off_t) i32;
	fn ualarm(useconds_t, useconds_t) useconds_t;
	fn usleep(useconds_t) i32;
	fn vfork() pid_t;

}
