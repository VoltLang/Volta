/**
 * From D header file for POSIX.
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
module core.c.posix.arpa.inet;

version (Posix):

public import core.c.posix.sys.socket; // for socklen_t

extern (C):

//
// Required
//
/*
NOTE: The following must must be defined in core.sys.posix.arpa.inet to break
      a circular import: in_port_t, in_addr_t, struct in_addr, INET_ADDRSTRLEN.

in_port_t // from core.sys.posix.netinet.in_
in_addr_t // from core.sys.posix.netinet.in_

struct in_addr  // from core.sys.posix.netinet.in_
INET_ADDRSTRLEN // from core.sys.posix.netinet.in_

uint32_t // from core.stdc.inttypes
uint16_t // from core.stdc.inttypes

uint32_t htonl(uint32_t);
uint16_t htons(uint16_t);
uint32_t ntohl(uint32_t);
uint16_t ntohs(uint16_t);

in_addr_t inet_addr(in char*);
char*     inet_ntoa(in_addr);
// per spec: const char* inet_ntop(int, const void*, char*, socklen_t);
char*     inet_ntop(int, in void*, char*, socklen_t);
int       inet_pton(int, in char*, void*);
*/

version (Linux) {

    alias in_port_t = u16;
    alias in_addr_t = u32;

    struct in_addr
    {
        s_addr: in_addr_t;
    }

    enum INET_ADDRSTRLEN = 16;

    fn htonl(u32) u32;
    fn htons(u16) u16;
    fn ntohl(u32) u32;
    fn ntohs(u16) u16;

	fn inet_addr(in char*) in_addr_t;
	fn inet_ntoa(in_addr) char*;
	fn inet_ntop(i32, in void*, char*, socklen_t) const(char)*;
	fn inet_pton(i32, in char*, void*) i32;

	enum INET6_ADDRSTRLEN = 46;

} else version (OSX) {

    alias in_port_t = u16;
    alias in_addr_t = u32;

    struct in_addr
    {
        s_addr: in_addr_t;
    }

    enum INET_ADDRSTRLEN = 16;

    fn htonl(u32) u32;
    fn htons(u16) u16;
    fn ntohl(u32) u32;
    fn ntohs(u16) u16;

	fn inet_addr(in char*) in_addr_t;
	fn inet_ntoa(in_addr) char*;
	fn inet_ntop(i32, in void*, char*, socklen_t) const(char)*;
	fn inet_pton(i32, in char*, void*) i32;

	enum INET6_ADDRSTRLEN = 46;

}
