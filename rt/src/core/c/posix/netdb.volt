/**
 * From D header file for POSIX.
 *
 * Copyright: Copyright David Nadlinger 2011.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   David Nadlinger, Sean Kelly, Alex Rønne Petersen
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */

/*          Copyright David Nadlinger 2011.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.c.posix.netdb;

version (Posix):

//private import core.sys.posix.config;
//public import core.stdc.inttypes;         // for uint32_t
public import core.c.posix.netinet.in_; // for in_port_t, in_addr_t
//public import core.sys.posix.sys.types;   // for ino_t
public import core.c.posix.sys.socket;  // for socklen_t

extern (C):

//
// Required
//
/*
struct hostent
{
    char*   h_name;
    char**  h_aliases;
    int     h_addrtype;
    int     h_length;
    char**  h_addr_list;
}

struct netent
{
    char*   n_name;
    char**  n_aliase;
    int     n_addrtype;
    uint32_t n_net;
}

struct protoent
{
    char*   p_name;
    char**  p_aliases;
    int     p_proto;
}

struct servent
{
    char*   s_name;
    char**  s_aliases;
    int     s_port;
    char*   s_proto;
}

IPPORT_RESERVED

h_errno

HOST_NOT_FOUND
NO_DATA
NO_RECOVERY
TRY_AGAIN

struct addrinfo
{
    int         ai_flags;
    int         ai_family;
    int         ai_socktype;
    int         ai_protocol;
    socklen_t   ai_addrlen;
    sockaddr*   ai_addr;
    char*       ai_canonname;
    addrinfo*   ai_next;
}

AI_PASSIVE
AI_CANONNAME
AI_NUMERICHOST
AI_NUMERICSERV
AI_V4MAPPED
AI_ALL
AI_ADDRCONFIG

NI_NOFQDN
NI_NUMERICHOST
NI_NAMEREQD
NI_NUMERICSERV
NI_NUMERICSCOPE
NI_DGRAM

EAI_AGAIN
EAI_BADFLAGS
EAI_FAIL
EAI_FAMILY
EAI_MEMORY
EAI_NONAME

EAI_SERVICE
EAI_SOCKTYPE
EAI_SYSTEM
EAI_OVERFLOW

void         endhostent();
void         endnetent();
void         endprotoent();
void         endservent();
void         freeaddrinfo(addrinfo*);
const(char)* gai_strerror(int);
int          getaddrinfo(const(char)*, const(char)*, const(addrinfo)*, addrinfo**);
hostent*     gethostbyaddr(const(void)*, socklen_t, int);
hostent*     gethostbyname(const(char)*);
hostent*     gethostent();
int          getnameinfo(const(sockaddr)*, socklen_t, char*, socklen_t, char*, socklen_t, int);
netent*      getnetbyaddr(uint32_t, int);
netent*      getnetbyname(const(char)*);
netent*      getnetent();
protoent*    getprotobyname(const(char)*);
protoent*    getprotobynumber(int);
protoent*    getprotoent();
servent*     getservbyname(const(char)*, const(char)*);
servent*     getservbyport(int, const(char)*);
servent*     getservent();
void         sethostent(int);
void         setnetent(int);
void         setprotoent(int);
void         setservent(int);
*/

version( Linux )
{
    struct hostent
    {
		h_name: char*;
		h_aliases: char**;
		h_addrtype: i32;
		h_length: i32;
		h_addr_list: char**;
        @property fn h_addr() char* { return h_addr_list[0]; } // non-standard
    }

    struct netent
    {
		n_name: char*;
		n_aliases: char**;
		n_addrtype: i32;
		n_net: u32;
    }

    struct protoent
    {
		p_name: char*;
		p_aliases: char**;
		p_proto: i32;
    }

    struct servent
    {
		s_name: char*;
		s_aliases: char**;
		s_port: i32;
		s_proto: char*;
    }

    enum IPPORT_RESERVED = 1024;

    //h_errno

    enum HOST_NOT_FOUND = 1;
    enum NO_DATA        = 4;
    enum NO_RECOVERY    = 3;
    enum TRY_AGAIN      = 2;

    struct addrinfo
    {
		ai_flags: i32;
		ai_family: i32;
		ai_socktype: i32;
		ai_protocol: i32;
		ai_addrlen: socklen_t;
		ai_addr: sockaddr*;
		ai_canonname: char*;
		ai_next: addrinfo*;
    }

    enum AI_PASSIVE         = 0x1;
    enum AI_CANONNAME       = 0x2;
    enum AI_NUMERICHOST     = 0x4;
    enum AI_NUMERICSERV     = 0x400;
    enum AI_V4MAPPED        = 0x8;
    enum AI_ALL             = 0x10;
    enum AI_ADDRCONFIG      = 0x20;

    enum NI_NOFQDN          = 4;
    enum NI_NUMERICHOST     = 1;
    enum NI_NAMEREQD        = 8;
    enum NI_NUMERICSERV     = 2;
    //enum NI_NUMERICSCOPE    = ?;
    enum NI_DGRAM           = 16;
    enum NI_MAXHOST         = 1025; // non-standard
    enum NI_MAXSERV         = 32;   // non-standard

    enum EAI_AGAIN          = -3;
    enum EAI_BADFLAGS       = -1;
    enum EAI_FAIL           = -4;
    enum EAI_FAMILY         = -6;
    enum EAI_MEMORY         = -10;
    enum EAI_NONAME         = -2;
    enum EAI_SERVICE        = -8;
    enum EAI_SOCKTYPE       = -7;
    enum EAI_SYSTEM         = -11;
    enum EAI_OVERFLOW       = -12;
}
else version( OSX )
{
    struct hostent
    {
		h_name: char*;
		h_aliases: char**;
		h_addrtype: i32;
		h_length: i32;
		h_addr_list: char**;
        @property fn   h_addr() char* { return h_addr_list[0]; } // non-standard
    }

    struct netent
    {
		n_name: char*;
		n_aliases: char**;
		n_addrtype: i32;
		n_net: u32;
    }

    struct protoent
    {
		p_name: char*;
		p_aliases: char**;
		p_proto: i32;
    }

    struct servent
    {
		s_name: char*;
		s_aliases: char**;
		s_port: i32;
		s_proto: char*;
    }

    enum IPPORT_RESERVED = 1024;

    //h_errno

    enum HOST_NOT_FOUND = 1;
    enum NO_DATA        = 4;
    enum NO_RECOVERY    = 3;
    enum TRY_AGAIN      = 2;

    struct addrinfo
    {
		ai_flags: i32;
		ai_family: i32;
		ai_socktype: i32;
		ai_protocol: i32;
		ai_addrlen: socklen_t;
		ai_canonname: char*;
		ai_addr: sockaddr*;
		ai_next: addrinfo*;
    }

    enum AI_PASSIVE         = 0x1;
    enum AI_CANONNAME       = 0x2;
    enum AI_NUMERICHOST     = 0x4;
    enum AI_NUMERICSERV     = 0x1000;
    enum AI_V4MAPPED        = 0x800;
    enum AI_ALL             = 0x100;
    enum AI_ADDRCONFIG      = 0x400;

    enum NI_NOFQDN          = 0x1;
    enum NI_NUMERICHOST     = 0x2;
    enum NI_NAMEREQD        = 0x4;
    enum NI_NUMERICSERV     = 0x8;
    //enum NI_NUMERICSCOPE    = ?;
    enum NI_DGRAM           = 0x10;
    enum NI_MAXHOST         = 1025; // non-standard
    enum NI_MAXSERV         = 32;   // non-standard

    enum EAI_AGAIN          = 2;
    enum EAI_BADFLAGS       = 3;
    enum EAI_FAIL           = 4;
    enum EAI_FAMILY         = 5;
    enum EAI_MEMORY         = 6;
    enum EAI_NONAME         = 8;
    enum EAI_SERVICE        = 9;
    enum EAI_SOCKTYPE       = 10;
    enum EAI_SYSTEM         = 11;
    enum EAI_OVERFLOW       = 14;
}
else
{
    static assert(false, "Unsupported platform");
}

fn endhostent();
fn endnetent();
fn endprotoent();
fn endservent();
fn freeaddrinfo(addrinfo*);
fn gai_strerror(i32) const(char)*;
fn getaddrinfo(const(char)*, const(char)*, const(addrinfo)*, addrinfo**) i32;
fn gethostbyaddr(const(void)*, socklen_t, int) hostent*;
fn gethostbyname(const(char)*) hostent*;
fn gethostent() hostent*;
fn getnameinfo(const(sockaddr)*, socklen_t, char*, socklen_t, char*, socklen_t, i32) i32;
fn getnetbyaddr(u32, i32) netent*;
fn getnetbyname(const(char)*) netent*;
fn getnetent() netent*;
fn getprotobyname(const(char)*) protoent*;
fn getprotobynumber(i32) protoent*;
fn getprotoent() protoent*;
fn getservbyname(const(char)*, const(char)*) servent*;
fn getservbyport(i32, const(char)*) servent*;
fn getservent() servent*;
fn sethostent(i32);
fn setnetent(i32);
fn setprotoent(i32);
fn setservent(i32);
