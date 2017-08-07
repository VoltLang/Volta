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
module core.c.posix.sys.socket;

version (Posix):

import core.c.config;
import core.c.posix.sys.uio;


extern (C) /*nothrow @nogc*/:

//
// Required
//
/*
socklen_t
sa_family_t

struct sockaddr
{
    sa_family_t sa_family;
    char        sa_data[];
}

struct sockaddr_storage
{
    sa_family_t ss_family;
}

struct msghdr
{
    void*         msg_name;
    socklen_t     msg_namelen;
    struct iovec* msg_iov;
    i32           msg_iovlen;
    void*         msg_control;
    socklen_t     msg_controllen;
    i32           msg_flags;
}

struct iovec {} // from core.sys.posix.sys.uio

struct cmsghdr
{
    socklen_t cmsg_len;
    i32       cmsg_level;
    i32       cmsg_type;
}

SCM_RIGHTS

CMSG_DATA(cmsg)
CMSG_NXTHDR(mhdr,cmsg)
CMSG_FIRSTHDR(mhdr)

struct linger
{
    i32 l_onoff;
    i32 l_linger;
}

SOCK_DGRAM
SOCK_SEQPACKET
SOCK_STREAM

SOL_SOCKET

SO_ACCEPTCONN
SO_BROADCAST
SO_DEBUG
SO_DONTROUTE
SO_ERROR
SO_KEEPALIVE
SO_LINGER
SO_OOBINLINE
SO_RCVBUF
SO_RCVLOWAT
SO_RCVTIMEO
SO_REUSEADDR
SO_SNDBUF
SO_SNDLOWAT
SO_SNDTIMEO
SO_TYPE

SOMAXCONN

MSG_CTRUNC
MSG_DONTROUTE
MSG_EOR
MSG_OOB
MSG_PEEK
MSG_TRUNC
MSG_WAITALL

AF_INET
AF_UNIX
AF_UNSPEC

SHUT_RD
SHUT_RDWR
SHUT_WR

i32     accept(i32, sockaddr*, socklen_t*);
i32     bind(i32, in sockaddr*, socklen_t);
i32     connect(i32, in sockaddr*, socklen_t);
i32     getpeername(i32, sockaddr*, socklen_t*);
i32     getsockname(i32, sockaddr*, socklen_t*);
i32     getsockopt(i32, i32, i32, void*, socklen_t*);
i32     listen(i32, i32);
ssize_t recv(i32, void*, size_t, i32);
ssize_t recvfrom(i32, void*, size_t, i32, sockaddr*, socklen_t*);
ssize_t recvmsg(i32, msghdr*, i32);
ssize_t send(i32, in void*, size_t, i32);
ssize_t sendmsg(i32, in msghdr*, i32);
ssize_t sendto(i32, in void*, size_t, i32, in sockaddr*, socklen_t);
i32     setsockopt(i32, i32, i32, in void*, socklen_t);
i32     shutdown(i32, i32);
i32     socket(i32, i32, i32);
i32     sockatmark(i32);
i32     socketpair(i32, i32, i32, ref i32[2]);
*/

version (Linux) {

    // Some of the constants below and from the Bionic section are really from
    // the linux kernel headers.
    alias socklen_t = u32;
    alias sa_family_t = u16;

    struct sockaddr
    {
        sa_family: sa_family_t;
        sa_data: i8[14];
    }

    private enum : size_t
    {
        _SS_SIZE    = 128,
        _SS_PADSIZE = 112 //_SS_SIZE - (typeid(c_ulong).size * 2)
    }

    struct sockaddr_storage
    {
        ss_family: sa_family_t;
        __ss_align: c_ulong;
        __ss_padding: i8[_SS_PADSIZE];
    }

    struct msghdr
    {
        msg_name: void*;
        msg_namelen: socklen_t;
        msg_iov: iovec*;
        msg_iovlen: size_t;
        msg_control: void*;
        msg_controllen: size_t;
        msg_flags: i32;
    }

    struct cmsghdr
    {
        cmsg_len: size_t;
        cmsg_level: i32;
        cmsg_type: i32;
    }

    enum : u32
    {
        SCM_RIGHTS = 0x01
    }

    struct linger
    {
        l_onoff: i32;
        l_linger: i32;
    }

    version (X86) {

        enum
        {
            SOCK_DGRAM      = 2,
            SOCK_SEQPACKET  = 5,
            SOCK_STREAM     = 1
        }

        enum
        {
            SOL_SOCKET      = 1
        }

        enum
        {
            SO_ACCEPTCONN   = 30,
            SO_BROADCAST    = 6,
            SO_DEBUG        = 1,
            SO_DONTROUTE    = 5,
            SO_ERROR        = 4,
            SO_KEEPALIVE    = 9,
            SO_LINGER       = 13,
            SO_OOBINLINE    = 10,
            SO_RCVBUF       = 8,
            SO_RCVLOWAT     = 18,
            SO_RCVTIMEO     = 20,
            SO_REUSEADDR    = 2,
            SO_SNDBUF       = 7,
            SO_SNDLOWAT     = 19,
            SO_SNDTIMEO     = 21,
            SO_TYPE         = 3
        }

    } else version (X86_64) {

        enum
        {
            SOCK_DGRAM      = 2,
            SOCK_SEQPACKET  = 5,
            SOCK_STREAM     = 1
        }

        enum
        {
            SOL_SOCKET      = 1
        }

        enum
        {
            SO_ACCEPTCONN   = 30,
            SO_BROADCAST    = 6,
            SO_DEBUG        = 1,
            SO_DONTROUTE    = 5,
            SO_ERROR        = 4,
            SO_KEEPALIVE    = 9,
            SO_LINGER       = 13,
            SO_OOBINLINE    = 10,
            SO_RCVBUF       = 8,
            SO_RCVLOWAT     = 18,
            SO_RCVTIMEO     = 20,
            SO_REUSEADDR    = 2,
            SO_SNDBUF       = 7,
            SO_SNDLOWAT     = 19,
            SO_SNDTIMEO     = 21,
            SO_TYPE         = 3
        }

    } else version (MIPS32) {

        enum
        {
            SOCK_DGRAM      = 1,
            SOCK_SEQPACKET  = 5,
            SOCK_STREAM     = 2,
        }

        enum
        {
            SOL_SOCKET      = 0xffff
        }

        enum
        {
            SO_ACCEPTCONN   = 0x1009,
            SO_BROADCAST    = 0x0020,
            SO_DEBUG        = 0x0001,
            SO_DONTROUTE    = 0x0010,
            SO_ERROR        = 0x1007,
            SO_KEEPALIVE    = 0x0008,
            SO_LINGER       = 0x0080,
            SO_OOBINLINE    = 0x0100,
            SO_RCVBUF       = 0x1002,
            SO_RCVLOWAT     = 0x1004,
            SO_RCVTIMEO     = 0x1006,
            SO_REUSEADDR    = 0x0004,
            SO_SNDBUF       = 0x1001,
            SO_SNDLOWAT     = 0x1003,
            SO_SNDTIMEO     = 0x1005,
            SO_TYPE         = 0x1008,
        }

    } else version (MIPS64) {

        enum
        {
            SOCK_DGRAM      = 1,
            SOCK_SEQPACKET  = 5,
            SOCK_STREAM     = 2,
        }

        enum
        {
            SOL_SOCKET      = 0xffff
        }

        enum
        {
            SO_ACCEPTCONN   = 0x1009,
            SO_BROADCAST    = 0x0020,
            SO_DEBUG        = 0x0001,
            SO_DONTROUTE    = 0x0010,
            SO_ERROR        = 0x1007,
            SO_KEEPALIVE    = 0x0008,
            SO_LINGER       = 0x0080,
            SO_OOBINLINE    = 0x0100,
            SO_RCVBUF       = 0x1002,
            SO_RCVLOWAT     = 0x1004,
            SO_RCVTIMEO     = 0x1006,
            SO_REUSEADDR    = 0x0004,
            SO_SNDBUF       = 0x1001,
            SO_SNDLOWAT     = 0x1003,
            SO_SNDTIMEO     = 0x1005,
            SO_TYPE         = 0x1008,
        }

    } else version (PPC) {

        enum
        {
            SOCK_DGRAM      = 2,
            SOCK_SEQPACKET  = 5,
            SOCK_STREAM     = 1
        }

        enum
        {
            SOL_SOCKET      = 1
        }

        enum
        {
            SO_ACCEPTCONN   = 30,
            SO_BROADCAST    = 6,
            SO_DEBUG        = 1,
            SO_DONTROUTE    = 5,
            SO_ERROR        = 4,
            SO_KEEPALIVE    = 9,
            SO_LINGER       = 13,
            SO_OOBINLINE    = 10,
            SO_RCVBUF       = 8,
            SO_RCVLOWAT     = 16,
            SO_RCVTIMEO     = 18,
            SO_REUSEADDR    = 2,
            SO_SNDBUF       = 7,
            SO_SNDLOWAT     = 17,
            SO_SNDTIMEO     = 19,
            SO_TYPE         = 3
        }

    } else version (PPC64) {

        enum
        {
            SOCK_DGRAM      = 2,
            SOCK_SEQPACKET  = 5,
            SOCK_STREAM     = 1
        }

        enum
        {
            SOL_SOCKET      = 1
        }

        enum
        {
            SO_ACCEPTCONN   = 30,
            SO_BROADCAST    = 6,
            SO_DEBUG        = 1,
            SO_DONTROUTE    = 5,
            SO_ERROR        = 4,
            SO_KEEPALIVE    = 9,
            SO_LINGER       = 13,
            SO_OOBINLINE    = 10,
            SO_RCVBUF       = 8,
            SO_RCVLOWAT     = 16,
            SO_RCVTIMEO     = 18,
            SO_REUSEADDR    = 2,
            SO_SNDBUF       = 7,
            SO_SNDLOWAT     = 17,
            SO_SNDTIMEO     = 19,
            SO_TYPE         = 3
        }

    } else version (AArch64) {

        enum
        {
            SOCK_DGRAM      = 2,
            SOCK_SEQPACKET  = 5,
            SOCK_STREAM     = 1
        }

        enum
        {
            SOL_SOCKET      = 1
        }

        enum
        {
            SO_ACCEPTCONN   = 30,
            SO_BROADCAST    = 6,
            SO_DEBUG        = 1,
            SO_DONTROUTE    = 5,
            SO_ERROR        = 4,
            SO_KEEPALIVE    = 9,
            SO_LINGER       = 13,
            SO_OOBINLINE    = 10,
            SO_RCVBUF       = 8,
            SO_RCVLOWAT     = 18,
            SO_RCVTIMEO     = 20,
            SO_REUSEADDR    = 2,
            SO_SNDBUF       = 7,
            SO_SNDLOWAT     = 19,
            SO_SNDTIMEO     = 21,
            SO_TYPE         = 3
        }

    } else version (ARM) {

        enum
        {
            SOCK_DGRAM      = 2,
            SOCK_SEQPACKET  = 5,
            SOCK_STREAM     = 1
        }

        enum
        {
            SOL_SOCKET      = 1
        }

        enum
        {
            SO_ACCEPTCONN   = 30,
            SO_BROADCAST    = 6,
            SO_DEBUG        = 1,
            SO_DONTROUTE    = 5,
            SO_ERROR        = 4,
            SO_KEEPALIVE    = 9,
            SO_LINGER       = 13,
            SO_OOBINLINE    = 10,
            SO_RCVBUF       = 8,
            SO_RCVLOWAT     = 18,
            SO_RCVTIMEO     = 20,
            SO_REUSEADDR    = 2,
            SO_SNDBUF       = 7,
            SO_SNDLOWAT     = 19,
            SO_SNDTIMEO     = 21,
            SO_TYPE         = 3
        }

    } else version (SystemZ) {

        enum
        {
            SOCK_DGRAM      = 2,
            SOCK_SEQPACKET  = 5,
            SOCK_STREAM     = 1
        }

        enum
        {
            SOL_SOCKET      = 1
        }

        enum
        {
            SO_ACCEPTCONN   = 30,
            SO_BROADCAST    = 6,
            SO_DEBUG        = 1,
            SO_DONTROUTE    = 5,
            SO_ERROR        = 4,
            SO_KEEPALIVE    = 9,
            SO_LINGER       = 13,
            SO_OOBINLINE    = 10,
            SO_RCVBUF       = 8,
            SO_RCVLOWAT     = 18,
            SO_RCVTIMEO     = 20,
            SO_REUSEADDR    = 2,
            SO_SNDBUF       = 7,
            SO_SNDLOWAT     = 19,
            SO_SNDTIMEO     = 21,
            SO_TYPE         = 3
        }

    } else {

        static assert(false, "unsupported arch");

    }

    enum
    {
        SOMAXCONN       = 128
    }

    enum : u32
    {
        MSG_CTRUNC      = 0x08,
        MSG_DONTROUTE   = 0x04,
        MSG_EOR         = 0x80,
        MSG_OOB         = 0x01,
        MSG_PEEK        = 0x02,
        MSG_TRUNC       = 0x20,
        MSG_WAITALL     = 0x100,
        MSG_NOSIGNAL    = 0x4000
    }

    enum
    {
        AF_APPLETALK    = 5,
        AF_INET         = 2,
        AF_IPX          = 4,
        AF_UNIX         = 1,
        AF_UNSPEC       = 0,
        PF_APPLETALK    = AF_APPLETALK,
        PF_IPX          = AF_IPX
    }

    enum i32 SOCK_RDM   = 4;

    enum
    {
        SHUT_RD,
        SHUT_WR,
        SHUT_RDWR
    }

    fn accept(i32, sockaddr*, socklen_t*) i32;
    fn bind(i32, in sockaddr*, socklen_t) i32;
    fn connect(i32, in sockaddr*, socklen_t) i32;
    fn getpeername(i32, sockaddr*, socklen_t*) i32;
    fn getsockname(i32, sockaddr*, socklen_t*) i32;
    fn getsockopt(i32, i32, i32, void*, socklen_t*) i32;
	fn listen(i32, i32) i32;
    fn recv(i32, void*, size_t, i32) ssize_t;
    fn recvfrom(i32, void*, size_t, i32, sockaddr*, socklen_t*) ssize_t;
    fn recvmsg(i32, msghdr*, i32) ssize_t;
    fn send(i32, in void*, size_t, i32) ssize_t;
    fn sendmsg(i32, in msghdr*, i32) ssize_t;
    fn sendto(i32, in void*, size_t, i32, in sockaddr*, socklen_t) ssize_t;
    fn setsockopt(i32, i32, i32, in void*, socklen_t) i32;
    fn shutdown(i32, i32) i32;
    fn socket(i32, i32, i32) i32;
    fn sockatmark(i32) i32;
    fn socketpair(i32, i32, i32, ref i32[2]) i32;

} else version (OSX) {

    alias socklen_t = u32;
    alias sa_family_t = u8;

    struct sockaddr
    {
        sa_len: u8;
        sa_family: sa_family_t;
        sa_data: i8[14];
    }

    private enum : size_t
    {
        _SS_PAD1    = 6,//typeid(i64).size - typeid(i8).size - typeid(sa_family_t).size,
        _SS_PAD2    = 119//128 - typeid(u8).size - typeid(sa_family_t).size - _SS_PAD1 - typeid(i8).size
    }

    struct sockaddr_storage
    {
         ss_len: u8;
         ss_family: sa_family_t;
         __ss_Pad1: i8[_SS_PAD1];
         __ss_align: i64;
         __ss_pad2: i8[_SS_PAD2];
    }

    struct msghdr
    {
        msg_name: void*;
        msg_namelen: socklen_t;
        msg_iov: iovec*;
        msg_iovlen: i32;
        msg_control: void*;
        msg_controllen: socklen_t;
        msg_flags: i32;
    }

    struct cmsghdr
    {
         cmsg_len: socklen_t;
         cmsg_level: i32;
         cmsg_type: i32;
    }

    enum : u32
    {
        SCM_RIGHTS = 0x01
    }

    /+
    CMSG_DATA(cmsg)     ((unsigned char *)(cmsg) + \
                         ALIGN(sizeof(struct cmsghdr)))
    CMSG_NXTHDR(mhdr, cmsg) \
                        (((unsigned char *)(cmsg) + ALIGN((cmsg)->cmsg_len) + \
                         ALIGN(sizeof(struct cmsghdr)) > \
                         (unsigned char *)(mhdr)->msg_control +(mhdr)->msg_controllen) ? \
                         (struct cmsghdr *)0 /* NULL */ : \
                         (struct cmsghdr *)((unsigned char *)(cmsg) + ALIGN((cmsg)->cmsg_len)))
    CMSG_FIRSTHDR(mhdr) ((struct cmsghdr *)(mhdr)->msg_control)
    +/

    struct linger
    {
        l_onoff: i32;
        l_linger: i32;
    }

    enum
    {
        SOCK_DGRAM      = 2,
        SOCK_RDM        = 4,
        SOCK_SEQPACKET  = 5,
        SOCK_STREAM     = 1
    }

    enum : u32
    {
        SOL_SOCKET      = 0xffff
    }

    enum : u32
    {
        SO_ACCEPTCONN   = 0x0002,
        SO_BROADCAST    = 0x0020,
        SO_DEBUG        = 0x0001,
        SO_DONTROUTE    = 0x0010,
        SO_ERROR        = 0x1007,
        SO_KEEPALIVE    = 0x0008,
        SO_LINGER       = 0x1080,
        SO_NOSIGPIPE    = 0x1022, // non-standard
        SO_OOBINLINE    = 0x0100,
        SO_RCVBUF       = 0x1002,
        SO_RCVLOWAT     = 0x1004,
        SO_RCVTIMEO     = 0x1006,
        SO_REUSEADDR    = 0x0004,
        SO_SNDBUF       = 0x1001,
        SO_SNDLOWAT     = 0x1003,
        SO_SNDTIMEO     = 0x1005,
        SO_TYPE         = 0x1008
    }

    enum
    {
        SOMAXCONN       = 128
    }

    enum : u32
    {
        MSG_CTRUNC      = 0x20,
        MSG_DONTROUTE   = 0x4,
        MSG_EOR         = 0x8,
        MSG_OOB         = 0x1,
        MSG_PEEK        = 0x2,
        MSG_TRUNC       = 0x10,
        MSG_WAITALL     = 0x40
    }

    enum
    {
        AF_APPLETALK    = 16,
        AF_INET         = 2,
        AF_IPX          = 23,
        AF_UNIX         = 1,
        AF_UNSPEC       = 0,
        PF_APPLETALK    = AF_APPLETALK,
        PF_IPX          = AF_IPX
    }

    enum
    {
        SHUT_RD,
        SHUT_WR,
        SHUT_RDWR
    }

    fn accept(i32, sockaddr*, socklen_t*) i32;
    fn bind(i32, in sockaddr*, socklen_t) i32;
    fn connect(i32, in sockaddr*, socklen_t) i32;
    fn getpeername(i32, sockaddr*, socklen_t*) i32;
    fn getsockname(i32, sockaddr*, socklen_t*) i32;
    fn getsockopt(i32, i32, i32, void*, socklen_t*) i32;
    fn listen(i32, i32) i32;
    fn recv(i32, void*, size_t, i32) ssize_t;
    fn recvfrom(i32, void*, size_t, i32, sockaddr*, socklen_t*) ssize_t;
    fn recvmsg(i32, msghdr*, i32) ssize_t;
    fn send(i32, in void*, size_t, i32) ssize_t;
    fn sendmsg(i32, in msghdr*, i32) ssize_t;
    fn sendto(i32, in void*, size_t, i32, in sockaddr*, socklen_t) ssize_t;
    fn setsockopt(i32, i32, i32, in void*, socklen_t) i32;
    fn shutdown(i32, i32) i32;
    fn socket(i32, i32, i32) i32;
    fn sockatmark(i32) i32;
    fn socketpair(i32, i32, i32, ref i32[2]) i32;

}

//
// IPV6 (IP6)
//
/*
AF_INET6
*/

version (Linux) {

    enum
    {
        AF_INET6    = 10
    }

} else version (OSX) {

    enum
    {
        AF_INET6    = 30
    }

}

//
// Raw Sockets (RS)
//
/*
SOCK_RAW
*/

version (Linux) {

    enum
    {
        SOCK_RAW    = 3
    }

} else version (OSX) {

    enum
    {
        SOCK_RAW    = 3
    }

}
