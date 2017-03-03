/**
 * D header file for POSIX.
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
module core.c.posix.netinet.in_;

version (!Metal):

//private import core.sys.posix.config;
//public import core.stdc.inttypes; // for uint32_t, uint16_t, uint8_t
public import core.c.posix.arpa.inet;
public import core.c.posix.sys.socket; // for sa_family_t

version (Posix):
extern (C):

//
// Required
//
/*
NOTE: The following must must be defined in core.sys.posix.arpa.inet to break
      a circular import: in_port_t, in_addr_t, struct in_addr, INET_ADDRSTRLEN.

in_port_t
in_addr_t

sa_family_t // from core.sys.posix.sys.socket
uint8_t     // from core.stdc.inttypes
uint32_t    // from core.stdc.inttypes

struct in_addr
{
    in_addr_t   s_addr;
}

struct sockaddr_in
{
    sa_family_t sin_family;
    in_port_t   sin_port;
    in_addr     sin_addr;
}

IPPROTO_IP
IPPROTO_ICMP
IPPROTO_TCP
IPPROTO_UDP

INADDR_ANY
INADDR_BROADCAST

INET_ADDRSTRLEN

htonl() // from core.sys.posix.arpa.inet
htons() // from core.sys.posix.arpa.inet
ntohl() // from core.sys.posix.arpa.inet
ntohs() // from core.sys.posix.arpa.inet
*/

version( Linux )
{
    // Some networking constants are subtly different for glibc, linux kernel
    // constants are also provided below.
/+
    alias in_port_t = u16;
    alias in_addr_t = u32;

    struct in_addr
    {
		s_addr: in_addr_t;
    }+/

    private enum __SOCK_SIZE__ = 16;

    struct sockaddr_in
    {
		sin_family: sa_family_t;
		sin_port: in_port_t;
		sin_addr: in_addr;

        /* Pad to size of `struct sockaddr'. */
		
        __pad: u8[8];//__SOCK_SIZE__ - typeid(sa_family_t).size -
              //typeid(in_port_t).size - typeid(in_addr).size] __pad;
    }

    enum
    {
        IPPROTO_IP   = 0,
        IPPROTO_ICMP = 1,
        IPPROTO_IGMP = 2,
        IPPROTO_GGP  = 3,
        IPPROTO_TCP  = 6,
        IPPROTO_PUP  = 12,
        IPPROTO_UDP  = 17,
        IPPROTO_IDP  = 22,
        IPPROTO_ND   = 77,
        IPPROTO_MAX  = 256
    }

    enum : uint
    {
        INADDR_ANY       = 0x00000000,
        INADDR_BROADCAST = 0xffffffffu,
        INADDR_LOOPBACK  = 0x7F000001u,
        INADDR_NONE      = 0xFFFFFFFFu
    }

    //enum INET_ADDRSTRLEN       = 16;
}
else version( OSX )
{/+
    alias in_port_t = u16;
    alias in_addr_t = u32;

    struct in_addr
    {
		s_addr: in_addr_t;
    }+/

    private enum __SOCK_SIZE__ = 16;

    struct sockaddr_in
    {
		sin_len: u8;
		sin_family: sa_family_t;
		sin_port: in_port_t;
		sin_addr: in_addr;
		sin_zero: u8[8];
    }

    enum
    {
        IPPROTO_IP   = 0,
        IPPROTO_ICMP = 1,
        IPPROTO_IGMP = 2,
        IPPROTO_GGP  = 3,
        IPPROTO_TCP  = 6,
        IPPROTO_PUP  = 12,
        IPPROTO_UDP  = 17,
        IPPROTO_IDP  = 22,
        IPPROTO_ND   = 77,
        IPPROTO_MAX  = 256
    }

    enum : uint
    {
        INADDR_ANY       = 0x00000000,
        INADDR_BROADCAST = 0xffffffffu,
        INADDR_LOOPBACK  = 0x7F000001u,
        INADDR_NONE      = 0xFFFFFFFFu
    }

    //enum INET_ADDRSTRLEN       = 16;
}

//
// IPV6 (IP6)
//
/*
NOTE: The following must must be defined in core.sys.posix.arpa.inet to break
      a circular import: INET6_ADDRSTRLEN.

struct in6_addr
{
    uint8_t[16] s6_addr;
}

struct sockaddr_in6
{
    sa_family_t sin6_family;
    in_port_t   sin6_port;
    uint32_t    sin6_flowinfo;
    in6_addr    sin6_addr;
    uint32_t    sin6_scope_id;
}

extern in6_addr in6addr_any;
extern in6_addr in6addr_loopback;

struct ipv6_mreq
{
    in6_addr    ipv6mr_multiaddr;
    uint        ipv6mr_interface;
}

IPPROTO_IPV6

INET6_ADDRSTRLEN

IPV6_JOIN_GROUP
IPV6_LEAVE_GROUP
IPV6_MULTICAST_HOPS
IPV6_MULTICAST_IF
IPV6_MULTICAST_LOOP
IPV6_UNICAST_HOPS
IPV6_V6ONLY

// macros
int IN6_IS_ADDR_UNSPECIFIED(in6_addr*)
int IN6_IS_ADDR_LOOPBACK(in6_addr*)
int IN6_IS_ADDR_MULTICAST(in6_addr*)
int IN6_IS_ADDR_LINKLOCAL(in6_addr*)
int IN6_IS_ADDR_SITELOCAL(in6_addr*)
int IN6_IS_ADDR_V4MAPPED(in6_addr*)
int IN6_IS_ADDR_V4COMPAT(in6_addr*)
int IN6_IS_ADDR_MC_NODELOCAL(in6_addr*)
int IN6_IS_ADDR_MC_LINKLOCAL(in6_addr*)
int IN6_IS_ADDR_MC_SITELOCAL(in6_addr*)
int IN6_IS_ADDR_MC_ORGLOCAL(in6_addr*)
int IN6_IS_ADDR_MC_GLOBAL(in6_addr*)
*/

version ( Linux )
{
    struct in6_addr
    {
        union _u
        {
            s6_addr: u8[16];
            s6_addr16: u16[8];
            s6_addr32: u32[4];
        }
        u: _u;

        @property fn s6_addr() u8[16]
        {
            return u.s6_addr;
        }

        @property fn s6_addr(val: u8[16])
        {
            u.s6_addr = val;
        }
    }

    struct sockaddr_in6
    {
        sin6_family: sa_family_t;
        sin6_port: in_port_t;
        sin6_flowinfo: u32;
        sin6_addr: in6_addr;
        sin6_scope_id: u32;
    }

    extern global in6addr_any: immutable(in6_addr);
    extern global in6addr_loopback: immutable(in6_addr);

    struct ipv6_mreq
    {
        ipv6mr_multiaddr: in6_addr;
        ipv6mr_interface: u32;
    }

    enum : u32
    {
        IPPROTO_IPV6        = 41U,

        //INET6_ADDRSTRLEN    = 46,

        IPV6_JOIN_GROUP     = 20,
        IPV6_LEAVE_GROUP    = 21,
        IPV6_MULTICAST_HOPS = 18,
        IPV6_MULTICAST_IF   = 17,
        IPV6_MULTICAST_LOOP = 19,
        IPV6_UNICAST_HOPS   = 16,
        IPV6_V6ONLY         = 26
    }

    // (not really) macros
    extern (Volt) fn IN6_IS_ADDR_UNSPECIFIED( addr: in6_addr* ) i32
    {
        return (cast(u32*) addr)[0] == 0 &&
               (cast(u32*) addr)[1] == 0 &&
               (cast(u32*) addr)[2] == 0 &&
               (cast(u32*) addr)[3] == 0;
    }

    extern (Volt) fn IN6_IS_ADDR_LOOPBACK( addr: in6_addr* ) i32
    {
        return (cast(u32*) addr)[0] == 0  &&
               (cast(u32*) addr)[1] == 0  &&
               (cast(u32*) addr)[2] == 0  &&
               (cast(u32*) addr)[3] == htonl( 1 );
    }

    extern (Volt) fn IN6_IS_ADDR_MULTICAST( addr: in6_addr* ) i32
    {
        return (cast(u8*) addr)[0] == 0xff;
    }

    extern (Volt) fn IN6_IS_ADDR_LINKLOCAL( addr: in6_addr* ) i32
    {
        return ((cast(u32*) addr)[0] & htonl( 0xffc00000u )) == htonl( 0xfe800000u );
    }

    extern (Volt) fn IN6_IS_ADDR_SITELOCAL( addr: in6_addr* ) i32
    {
        return ((cast(u32*) addr)[0] & htonl( 0xffc00000u )) == htonl( 0xfec00000u );
    }

    extern (Volt) fn IN6_IS_ADDR_V4MAPPED( addr: in6_addr* ) i32
    {
        return (cast(u32*) addr)[0] == 0 &&
               (cast(u32*) addr)[1] == 0 &&
               (cast(u32*) addr)[2] == htonl( 0xffff );
    }

    extern (Volt) fn IN6_IS_ADDR_V4COMPAT( addr: in6_addr* ) i32
    {
        return (cast(u32*) addr)[0] == 0 &&
               (cast(u32*) addr)[1] == 0 &&
               (cast(u32*) addr)[2] == 0 &&
               ntohl( (cast(u32*) addr)[3] ) > 1;
    }

    extern (Volt) fn IN6_IS_ADDR_MC_NODELOCAL( addr: in6_addr* ) i32
    {
        return IN6_IS_ADDR_MULTICAST( addr ) &&
               ((cast(u8*) addr)[1] & 0xf) == 0x1;
    }

    extern (Volt) fn IN6_IS_ADDR_MC_LINKLOCAL( addr: in6_addr* ) i32
    {
        return IN6_IS_ADDR_MULTICAST( addr ) &&
               ((cast(u8*) addr)[1] & 0xf) == 0x2;
    }

    extern (Volt) fn IN6_IS_ADDR_MC_SITELOCAL( addr: in6_addr* ) i32
    {
        return IN6_IS_ADDR_MULTICAST(addr) &&
               ((cast(u8*) addr)[1] & 0xf) == 0x5;
    }

    extern (Volt) fn IN6_IS_ADDR_MC_ORGLOCAL( addr: in6_addr* ) i32
    {
        return IN6_IS_ADDR_MULTICAST( addr) &&
               ((cast(u8*) addr)[1] & 0xf) == 0x8;
    }

    extern (Volt) fn IN6_IS_ADDR_MC_GLOBAL( addr: in6_addr* ) i32
    {
        return IN6_IS_ADDR_MULTICAST( addr ) &&
               ((cast(u8*) addr)[1] & 0xf) == 0xe;
    }
}
else version( OSX )
{
    struct in6_addr
    {
        union _u
        {
            s6_addr: u8[16];
            s6_addr16: u16[8];
            s6_addr32: u32[4];
        }
        u: _u;

        @property fn s6_addr() u8[16]
        {
            return u.s6_addr;
        }

        @property fn s6_addr(val: u8[16])
        {
            u.s6_addr = val;
        }
    }

    struct sockaddr_in6
    {
        sin6_len: u8;
        sin6_family: sa_family_t;
        sin6_port: in_port_t;
        sin6_flowinfo: u32;
        sin6_addr: in6_addr;
        sin6_scope_id: u32;
    }

    extern global in6addr_any: immutable(in6_addr);
    extern global in6addr_loopback: immutable(in6_addr);

    struct ipv6_mreq
    {
        ipv6mr_multiaddr: in6_addr;
        ipv6mr_interface: u32;
    }

    enum : u32
    {
        IPPROTO_IPV6        = 41u,

        //INET6_ADDRSTRLEN    = 46,

        IPV6_JOIN_GROUP     = 12,
        IPV6_LEAVE_GROUP    = 13,
        IPV6_MULTICAST_HOPS = 10,
        IPV6_MULTICAST_IF   = 9,
        IPV6_MULTICAST_LOOP = 11,
        IPV6_UNICAST_HOPS   = 4,
        IPV6_V6ONLY         = 27
    }

    // (again, not really) macros
    extern (Volt) fn IN6_IS_ADDR_UNSPECIFIED( addr: in6_addr* ) i32
    {
        return (cast(u32*) addr)[0] == 0 &&
               (cast(u32*) addr)[1] == 0 &&
               (cast(u32*) addr)[2] == 0 &&
               (cast(u32*) addr)[3] == 0;
    }

    extern (Volt) fn IN6_IS_ADDR_LOOPBACK( addr: in6_addr* ) i32
    {
        return (cast(u32*) addr)[0] == 0  &&
               (cast(u32*) addr)[1] == 0  &&
               (cast(u32*) addr)[2] == 0  &&
               (cast(u32*) addr)[3] == ntohl( 1 );
    }

    extern (Volt) fn IN6_IS_ADDR_MULTICAST( addr: in6_addr* ) i32
    {
        return addr.u.s6_addr[0] == 0xff;
    }

    extern (Volt) fn IN6_IS_ADDR_LINKLOCAL( addr: in6_addr* ) i32
    {
        return addr.u.s6_addr[0] == 0xfe && (addr.u.s6_addr[1] & 0xc0) == 0x80;
    }

    extern (Volt) fn IN6_IS_ADDR_SITELOCAL( addr: in6_addr* ) i32
    {
        return addr.u.s6_addr[0] == 0xfe && (addr.u.s6_addr[1] & 0xc0) == 0xc0;
    }

    extern (Volt) fn IN6_IS_ADDR_V4MAPPED( addr: in6_addr* ) i32
    {
        return (cast(u32*) addr)[0] == 0 &&
               (cast(u32*) addr)[1] == 0 &&
               (cast(u32*) addr)[2] == ntohl( 0x0000ffff );
    }

    extern (Volt) fn IN6_IS_ADDR_V4COMPAT( addr: in6_addr* ) i32
    {
        return (cast(u32*) addr)[0] == 0 &&
               (cast(u32*) addr)[1] == 0 &&
               (cast(u32*) addr)[2] == 0 &&
               (cast(u32*) addr)[3] != 0 &&
               (cast(u32*) addr)[3] != ntohl( 1 );
    }

    extern (Volt) fn IN6_IS_ADDR_MC_NODELOCAL( addr: in6_addr* ) i32
    {
        return IN6_IS_ADDR_MULTICAST( addr ) &&
               ((cast(u8*) addr)[1] & 0xf) == 0x1;
    }

    extern (Volt) fn IN6_IS_ADDR_MC_LINKLOCAL( addr: in6_addr* ) i32
    {
        return IN6_IS_ADDR_MULTICAST( addr ) &&
               ((cast(u8*) addr)[1] & 0xf) == 0x2;
    }

    extern (Volt) fn IN6_IS_ADDR_MC_SITELOCAL( addr: in6_addr* ) i32
    {
        return IN6_IS_ADDR_MULTICAST(addr) &&
               ((cast(u8*) addr)[1] & 0xf) == 0x5;
    }

    extern (Volt) fn IN6_IS_ADDR_MC_ORGLOCAL( addr: in6_addr* ) i32
    {
        return IN6_IS_ADDR_MULTICAST( addr) &&
               ((cast(u8*) addr)[1] & 0xf) == 0x8;
    }

    extern (Volt) fn IN6_IS_ADDR_MC_GLOBAL( addr: in6_addr* ) i32
    {
        return IN6_IS_ADDR_MULTICAST( addr ) &&
               ((cast(u8*) addr)[1] & 0xf) == 0xe;
    }
}


//
// Raw Sockets (RS)
//
/*
IPPROTO_RAW
*/

version( Linux )
{
    enum IPPROTO_RAW = 255;
}
else version( OSX )
{
    enum IPPROTO_RAW = 255;
}
