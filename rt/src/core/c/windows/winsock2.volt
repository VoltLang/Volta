/*
    Written by Christopher E. Miller
    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
*/


module core.c.windows.winsock2;
version (!Metal):
version (Windows):

extern(Windows):

alias SOCKET = size_t;
alias socklen_t = i32;

enum SOCKET INVALID_SOCKET = cast(SOCKET)~0;
enum int SOCKET_ERROR = -1;

enum WSADESCRIPTION_LEN = 256;
enum WSASYS_STATUS_LEN = 128;

struct WSADATA
{
    wVersion: u16;
    wHighVersion: u16;
    szDescription: char[WSADESCRIPTION_LEN + 1];
    szSystemStatus: char[WSASYS_STATUS_LEN + 1];
    iMaxSockets: u16;
    iMaxUdpDg: u16;
    lpVendorInfo: char*;
}
alias LPWSADATA = WSADATA*;


enum i32 IOCPARM_MASK =  0x7F;
enum i32 IOC_IN =        cast(i32)0x80000000;
enum i32 FIONBIO =       cast(i32)-2147195266;//(IOC_IN | ((cast(i32)typeid(u32).size & IOCPARM_MASK) << 16) | (102 << 8) | 126);

enum NI_MAXHOST = 1025;
enum NI_MAXSERV = 32;

fn WSAStartup(u16, LPWSADATA) i32;
fn WSACleanup() i32;
fn socket(i32, i32, i32) SOCKET;
fn ioctlsocket(SOCKET, i32, u32*) i32;
fn bind(SOCKET, const(sockaddr)*, socklen_t) i32;
fn connect(SOCKET, const(sockaddr)*, socklen_t) i32;
fn listen(SOCKET, i32);
fn accept(SOCKET, sockaddr*, socklen_t*) SOCKET;
fn closesocket(SOCKET) i32;
fn shutdown(SOCKET, i32) i32;
fn getpeername(SOCKET, sockaddr*, socklen_t*) i32;
fn getsockname(SOCKET, sockaddr*, socklen_t*) i32;
fn send(SOCKET, const(void)*, i32, i32) i32;
fn sendto(SOCKET, const(void)*, i32, i32, const(sockaddr)*, socklen_t) i32;
fn recv(SOCKET, void*, i32, i32) i32;
fn recvfrom(SOCKET, void*, i32, i32, sockaddr*, socklen_t*) i32;
fn getsockopt(SOCKET, i32, i32, void*, socklen_t*) i32;
fn setsockopt(SOCKET, i32, i32, const(void)*, socklen_t) i32;
fn inet_addr(const char*) u32;
fn select(i32, fd_set*, fd_set*, fd_set*, const(timeval)*) i32;
fn inet_ntoa(in_addr) char*;
fn gethostbyname(const char*) hostent*;
fn gethostbyaddr(const(void)*, i32, i32) hostent*;
fn getprotobyname(const char*) protoent*;
fn getprotobynumber(i32) protoent*;
fn getservbyname(const char*, const char*) servent*;
fn getservbyport(i32, const char*) servent*;

enum: i32
{
    NI_NOFQDN =          0x01,
    NI_NUMERICHOST =     0x02,
    NI_NAMEREQD =        0x04,
    NI_NUMERICSERV =     0x08,
    NI_DGRAM  =          0x10,
}

fn gethostname(const char*, i32) i32;
fn getaddrinfo(const(char)*, const(char)*, const(addrinfo)*, addrinfo**) i32;
fn freeaddrinfo(addrinfo*);
fn getnameinfo(const(sockaddr)*, socklen_t, char*, u32, char*, u32, i32) i32;

enum WSABASEERR = 10000;

enum: i32
{
    /*
     * Windows Sockets definitions of regular Microsoft C error constants
     */
    WSAEINTR = (WSABASEERR+4),
    WSAEBADF = (WSABASEERR+9),
    WSAEACCES = (WSABASEERR+13),
    WSAEFAULT = (WSABASEERR+14),
    WSAEINVAL = (WSABASEERR+22),
    WSAEMFILE = (WSABASEERR+24),

    /*
     * Windows Sockets definitions of regular Berkeley error constants
     */
    WSAEWOULDBLOCK = (WSABASEERR+35),
    WSAEINPROGRESS = (WSABASEERR+36),
    WSAEALREADY = (WSABASEERR+37),
    WSAENOTSOCK = (WSABASEERR+38),
    WSAEDESTADDRREQ = (WSABASEERR+39),
    WSAEMSGSIZE = (WSABASEERR+40),
    WSAEPROTOTYPE = (WSABASEERR+41),
    WSAENOPROTOOPT = (WSABASEERR+42),
    WSAEPROTONOSUPPORT = (WSABASEERR+43),
    WSAESOCKTNOSUPPORT = (WSABASEERR+44),
    WSAEOPNOTSUPP = (WSABASEERR+45),
    WSAEPFNOSUPPORT = (WSABASEERR+46),
    WSAEAFNOSUPPORT = (WSABASEERR+47),
    WSAEADDRINUSE = (WSABASEERR+48),
    WSAEADDRNOTAVAIL = (WSABASEERR+49),
    WSAENETDOWN = (WSABASEERR+50),
    WSAENETUNREACH = (WSABASEERR+51),
    WSAENETRESET = (WSABASEERR+52),
    WSAECONNABORTED = (WSABASEERR+53),
    WSAECONNRESET = (WSABASEERR+54),
    WSAENOBUFS = (WSABASEERR+55),
    WSAEISCONN = (WSABASEERR+56),
    WSAENOTCONN = (WSABASEERR+57),
    WSAESHUTDOWN = (WSABASEERR+58),
    WSAETOOMANYREFS = (WSABASEERR+59),
    WSAETIMEDOUT = (WSABASEERR+60),
    WSAECONNREFUSED = (WSABASEERR+61),
    WSAELOOP = (WSABASEERR+62),
    WSAENAMETOOLONG = (WSABASEERR+63),
    WSAEHOSTDOWN = (WSABASEERR+64),
    WSAEHOSTUNREACH = (WSABASEERR+65),
    WSAENOTEMPTY = (WSABASEERR+66),
    WSAEPROCLIM = (WSABASEERR+67),
    WSAEUSERS = (WSABASEERR+68),
    WSAEDQUOT = (WSABASEERR+69),
    WSAESTALE = (WSABASEERR+70),
    WSAEREMOTE = (WSABASEERR+71),

    /*
     * Extended Windows Sockets error constant definitions
     */
    WSASYSNOTREADY = (WSABASEERR+91),
    WSAVERNOTSUPPORTED = (WSABASEERR+92),
    WSANOTINITIALISED = (WSABASEERR+93),

    /* Authoritative Answer: Host not found */
    WSAHOST_NOT_FOUND = (WSABASEERR+1001),
    HOST_NOT_FOUND = WSAHOST_NOT_FOUND,

    /* Non-Authoritative: Host not found, or SERVERFAIL */
    WSATRY_AGAIN = (WSABASEERR+1002),
    TRY_AGAIN = WSATRY_AGAIN,

    /* Non recoverable errors, FORMERR, REFUSED, NOTIMP */
    WSANO_RECOVERY = (WSABASEERR+1003),
    NO_RECOVERY = WSANO_RECOVERY,

    /* Valid name, no data record of requested type */
    WSANO_DATA = (WSABASEERR+1004),
    NO_DATA = WSANO_DATA,

    /* no address, look for MX record */
    WSANO_ADDRESS = WSANO_DATA,
    NO_ADDRESS = WSANO_ADDRESS
}

/*
 * Windows Sockets errors redefined as regular Berkeley error constants
 */
enum: int
{
    EWOULDBLOCK = WSAEWOULDBLOCK,
    EINPROGRESS = WSAEINPROGRESS,
    EALREADY = WSAEALREADY,
    ENOTSOCK = WSAENOTSOCK,
    EDESTADDRREQ = WSAEDESTADDRREQ,
    EMSGSIZE = WSAEMSGSIZE,
    EPROTOTYPE = WSAEPROTOTYPE,
    ENOPROTOOPT = WSAENOPROTOOPT,
    EPROTONOSUPPORT = WSAEPROTONOSUPPORT,
    ESOCKTNOSUPPORT = WSAESOCKTNOSUPPORT,
    EOPNOTSUPP = WSAEOPNOTSUPP,
    EPFNOSUPPORT = WSAEPFNOSUPPORT,
    EAFNOSUPPORT = WSAEAFNOSUPPORT,
    EADDRINUSE = WSAEADDRINUSE,
    EADDRNOTAVAIL = WSAEADDRNOTAVAIL,
    ENETDOWN = WSAENETDOWN,
    ENETUNREACH = WSAENETUNREACH,
    ENETRESET = WSAENETRESET,
    ECONNABORTED = WSAECONNABORTED,
    ECONNRESET = WSAECONNRESET,
    ENOBUFS = WSAENOBUFS,
    EISCONN = WSAEISCONN,
    ENOTCONN = WSAENOTCONN,
    ESHUTDOWN = WSAESHUTDOWN,
    ETOOMANYREFS = WSAETOOMANYREFS,
    ETIMEDOUT = WSAETIMEDOUT,
    ECONNREFUSED = WSAECONNREFUSED,
    ELOOP = WSAELOOP,
    ENAMETOOLONG = WSAENAMETOOLONG,
    EHOSTDOWN = WSAEHOSTDOWN,
    EHOSTUNREACH = WSAEHOSTUNREACH,
    ENOTEMPTY = WSAENOTEMPTY,
    EPROCLIM = WSAEPROCLIM,
    EUSERS = WSAEUSERS,
    EDQUOT = WSAEDQUOT,
    ESTALE = WSAESTALE,
    EREMOTE = WSAEREMOTE
}

enum: i32
{
    EAI_NONAME    = WSAHOST_NOT_FOUND,
}

fn WSAGetLastError() i32;


enum: i32
{
    AF_UNSPEC =     0,

    AF_UNIX =       1,
    AF_INET =       2,
    AF_IMPLINK =    3,
    AF_PUP =        4,
    AF_CHAOS =      5,
    AF_NS =         6,
    AF_IPX =        AF_NS,
    AF_ISO =        7,
    AF_OSI =        AF_ISO,
    AF_ECMA =       8,
    AF_DATAKIT =    9,
    AF_CCITT =      10,
    AF_SNA =        11,
    AF_DECnet =     12,
    AF_DLI =        13,
    AF_LAT =        14,
    AF_HYLINK =     15,
    AF_APPLETALK =  16,
    AF_NETBIOS =    17,
    AF_VOICEVIEW =  18,
    AF_FIREFOX =    19,
    AF_UNKNOWN1 =   20,
    AF_BAN =        21,
    AF_ATM =        22,
    AF_INET6 =      23,
    AF_CLUSTER =    24,
    AF_12844 =      25,
    AF_IRDA =       26,
    AF_NETDES =     28,

    AF_MAX =        29,


    PF_UNSPEC     = AF_UNSPEC,

    PF_UNIX =       AF_UNIX,
    PF_INET =       AF_INET,
    PF_IMPLINK =    AF_IMPLINK,
    PF_PUP =        AF_PUP,
    PF_CHAOS =      AF_CHAOS,
    PF_NS =         AF_NS,
    PF_IPX =        AF_IPX,
    PF_ISO =        AF_ISO,
    PF_OSI =        AF_OSI,
    PF_ECMA =       AF_ECMA,
    PF_DATAKIT =    AF_DATAKIT,
    PF_CCITT =      AF_CCITT,
    PF_SNA =        AF_SNA,
    PF_DECnet =     AF_DECnet,
    PF_DLI =        AF_DLI,
    PF_LAT =        AF_LAT,
    PF_HYLINK =     AF_HYLINK,
    PF_APPLETALK =  AF_APPLETALK,
    PF_VOICEVIEW =  AF_VOICEVIEW,
    PF_FIREFOX =    AF_FIREFOX,
    PF_UNKNOWN1 =   AF_UNKNOWN1,
    PF_BAN =        AF_BAN,
    PF_INET6 =      AF_INET6,

    PF_MAX        = AF_MAX,
}


enum: i32
{
    SOL_SOCKET = 0xFFFF,
}


enum: i32
{
    SO_DEBUG =        0x0001,
    SO_ACCEPTCONN =   0x0002,
    SO_REUSEADDR =    0x0004,
    SO_KEEPALIVE =    0x0008,
    SO_DONTROUTE =    0x0010,
    SO_BROADCAST =    0x0020,
    SO_USELOOPBACK =  0x0040,
    SO_LINGER =       0x0080,
    SO_DONTLINGER =   ~SO_LINGER,
    SO_OOBINLINE =    0x0100,
    SO_SNDBUF =       0x1001,
    SO_RCVBUF =       0x1002,
    SO_SNDLOWAT =     0x1003,
    SO_RCVLOWAT =     0x1004,
    SO_SNDTIMEO =     0x1005,
    SO_RCVTIMEO =     0x1006,
    SO_ERROR =        0x1007,
    SO_TYPE =         0x1008,
    SO_EXCLUSIVEADDRUSE = ~SO_REUSEADDR,

    TCP_NODELAY =    1,

    IP_OPTIONS                  = 1,

    IP_HDRINCL                  = 2,
    IP_TOS                      = 3,
    IP_TTL                      = 4,
    IP_MULTICAST_IF             = 9,
    IP_MULTICAST_TTL            = 10,
    IP_MULTICAST_LOOP           = 11,
    IP_ADD_MEMBERSHIP           = 12,
    IP_DROP_MEMBERSHIP          = 13,
    IP_DONTFRAGMENT             = 14,
    IP_ADD_SOURCE_MEMBERSHIP    = 15,
    IP_DROP_SOURCE_MEMBERSHIP   = 16,
    IP_BLOCK_SOURCE             = 17,
    IP_UNBLOCK_SOURCE           = 18,
    IP_PKTINFO                  = 19,

    IPV6_UNICAST_HOPS =    4,
    IPV6_MULTICAST_IF =    9,
    IPV6_MULTICAST_HOPS =  10,
    IPV6_MULTICAST_LOOP =  11,
    IPV6_ADD_MEMBERSHIP =  12,
    IPV6_DROP_MEMBERSHIP = 13,
    IPV6_JOIN_GROUP =      IPV6_ADD_MEMBERSHIP,
    IPV6_LEAVE_GROUP =     IPV6_DROP_MEMBERSHIP,
    IPV6_V6ONLY = 27,
}


/// Default FD_SETSIZE value.
/// In C/C++, it is redefinable by #define-ing the macro before #include-ing
/// winsock.h. In D, use the $(D FD_CREATE) function to allocate a $(D fd_set)
/// of an arbitrary size.
enum int FD_SETSIZE = 64;

/+
struct fd_set_custom(uint SETSIZE)
{
    uint fd_count;
    SOCKET[SETSIZE] fd_array;
}+/

//alias fd_set = fd_set_custom!FD_SETSIZE;

struct fd_set
{
	fd_count: u32;
	fd_array: SOCKET[FD_SETSIZE];
}

struct fd_set_one
{
	fd_count: u32;
	fd_array: SOCKET[1];
}

fn FD_CLR(fd: SOCKET, set: fd_set*)
{
    c: u32 = set.fd_count;
    start: SOCKET* = set.fd_array.ptr;
    stop: SOCKET* = start + c;

	found := false;
    for(; start !is stop; start++)
    {
        if (*start == fd) {
            found = true;
			break;
		}
    }
	if (!found) {
    	return; //not found
	}

    for(++start; start !is stop; start++)
    {
        *(start - 1) = *start;
    }

    set.fd_count = c - 1;
}


// Tests.
fn FD_ISSET(fd: SOCKET, set: const(fd_set)*) i32
{
	start: const(SOCKET)* = set.fd_array.ptr;
	stop: const(SOCKET)* = start + set.fd_count;

    for(; start !is stop; start++)
    {
        if(*start == fd)
            return true;
    }
    return false;
}


// Adds.
fn FD_SET(fd: SOCKET, set: fd_set*)
{
    c: u32 = set.fd_count;
    set.fd_array.ptr[c] = fd;
    set.fd_count = c + 1;
}


// Resets to zero.
fn FD_ZERO(set: fd_set*)
{
    set.fd_count = 0;
}


/// Creates a new $(D fd_set) with the specified capacity.
fn FD_CREATE(capacity: u32) fd_set*
{
    // Take into account alignment (SOCKET may be 64-bit and require 64-bit alignment on 64-bit systems)
    size: size_t = typeid(fd_set_one).size - typeid(SOCKET).size + (typeid(SOCKET).size * capacity);
    data := new ubyte[](size);
    set := cast(fd_set*)data.ptr;
    FD_ZERO(set);
    return set;
}

struct linger
{
    l_onoff: u16;
    l_linger: u16;
}


struct protoent
{
    p_name: char*;
    p_aliases: char**;
    p_proto: i16;
}


struct servent
{
    s_name: char*;
    s_aliases: char**;

    version (V_LP64)
    {
        s_proto: char*;
        s_port: i16;
    }
    else
    {
        s_port: i16;
        s_proto: char*;
    }
}


/+
union in6_addr
{
    private union _u_t
    {
        ubyte[16] Byte;
        ushort[8] Word;
    }
    _u_t u;
}


struct in_addr6
{
    ubyte[16] s6_addr;
}
+/


fn htons(x: u16) u16
{
	return cast(u16)((x >> 8) | (x << 8));
}


fn htonl(x: u32) u32
{
	return ((x>>24)&0xff) | // move byte 3 to byte 0
			((x<<8)&0xff0000) | // move byte 1 to byte 2
    		((x>>8)&0xff00) | // move byte 2 to byte 1
    		((x<<24U)&0xff000000U); // byte 0 to byte 3
}



fn ntohs(x: u16) u16
{
    return htons(x);
}


fn ntohl(x: u32) u32
{
    return htonl(x);
}

enum: i32
{
    SOCK_STREAM =     1,
    SOCK_DGRAM =      2,
    SOCK_RAW =        3,
    SOCK_RDM =        4,
    SOCK_SEQPACKET =  5,
}


enum: i32
{
    IPPROTO_IP =    0,
    IPPROTO_ICMP =  1,
    IPPROTO_IGMP =  2,
    IPPROTO_GGP =   3,
    IPPROTO_TCP =   6,
    IPPROTO_PUP =   12,
    IPPROTO_UDP =   17,
    IPPROTO_IDP =   22,
    IPPROTO_IPV6 =  41,
    IPPROTO_ND =    77,
    IPPROTO_RAW =   255,

    IPPROTO_MAX =   256,
}


enum: i32
{
    MSG_OOB =        0x1,
    MSG_PEEK =       0x2,
    MSG_DONTROUTE =  0x4
}


enum: i32
{
    SD_RECEIVE =  0,
    SD_SEND =     1,
    SD_BOTH =     2,
}


enum: u32
{
    INADDR_ANY =        0,
    INADDR_LOOPBACK =   0x7F000001,
    INADDR_BROADCAST =  0xFFFFFFFFU,
    INADDR_NONE =       0xFFFFFFFFU,
    ADDR_ANY =          0,
}


enum: i32
{
    AI_PASSIVE = 0x1,
    AI_CANONNAME = 0x2,
    AI_NUMERICHOST = 0x4,
    AI_ADDRCONFIG = 0x0400,
    AI_NON_AUTHORITATIVE = 0x04000,
    AI_SECURE = 0x08000,
    AI_RETURN_PREFERRED_NAMES = 0x010000,
}


struct timeval
{
    tv_sec: i32;
    tv_usec: i32;
}


union in_addr
{
    private union _S_un_t
    {
        private struct _S_un_b_t
        {
            s_b1, s_b2, s_b3, s_b4: u8;
        }
        S_un_b: _S_un_b_t;

        private struct _S_un_w_t
        {
            s_w1, s_w2: u16;
        }
        S_un_w: _S_un_w_t;

        S_addr: u32;
    }
    S_un: _S_un_t;

    s_addr: u32;

    struct _s
    {
        s_net, s_host: u8;

        union _u
        {
            s_imp: u16;

            struct _s2
            {
                s_lh, s_impno: u8;
            }
			s2: _s2;
        }
		u: _u;
	}
	s: _s;	
}


union in6_addr
{
    private union _in6_u_t
    {
        u6_addr8: u8[16];
        u6_addr16: u16[8];
        u6_addr32: u32[4];
    }
    in6_u: _in6_u_t;

    s6_addr8: u8[16];
    s6_addr16: u16[8];
    s6_addr32: u32[4];

    alias s6_addr = s6_addr8;
}


//enum in6_addr IN6ADDR_ANY = { s6_addr8: [0] };
//enum in6_addr IN6ADDR_LOOPBACK = { s6_addr8: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1] };
//alias IN6ADDR_ANY_INIT = IN6ADDR_ANY;
//alias IN6ADDR_LOOPBACK_INIT = IN6ADDR_LOOPBACK;

enum i32 INET_ADDRSTRLEN = 16;
enum i32 INET6_ADDRSTRLEN = 46;




struct sockaddr
{
    sa_family: i16;
    sa_data: u8[14];
}
alias SOCKADDR = sockaddr;
alias PSOCKADDR = SOCKADDR*;
alias LPSOCKADDR = SOCKADDR*;

struct SOCKADDR_STORAGE
{
    ss_family: i16;
    __ss_pad1: char[6];
    __ss_align: i64;
    __ss_pad2: char[112];
}
alias PSOCKADDR_STORAGE = SOCKADDR_STORAGE*;

struct sockaddr_in
{
    sin_family: i16;// = AF_INET;
    sin_port: u16;
    sin_addr: in_addr;
    sin_zero: u8[8];
}
alias SOCKADDR_IN = sockaddr_in;
alias PSOCKADDR_IN = SOCKADDR_IN*;
alias LPSOCKADDR_IN = SOCKADDR_IN*;


struct sockaddr_in6
{
    sin6_family: i16;// = AF_INET6;
    sin6_port: u16;
    sin6_flowinfo: u32;
    sin6_addr: in6_addr;
    sin6_scope_id: u32;
}


struct addrinfo
{
    ai_flags: i32;
    ai_family: i32;
    ai_socktype: i32;
    ai_protocol: i32;
    ai_addrlen: size_t;
    ai_canonname: char*;
    ai_addr: sockaddr*;
    ai_next: addrinfo*;
}


struct hostent
{
    h_name: char*;
    h_aliases: char**;
    h_addrtype: i16;
    h_length: i16;
    h_addr_list: char**;


    char* h_addr()
    {
        return h_addr_list[0];
    }
}

// Note: These are Winsock2!!
struct WSAOVERLAPPED {}
alias LPWSAOVERLAPPED = WSAOVERLAPPED*;
alias LPWSAOVERLAPPED_COMPLETION_ROUTINE = fn(u32, u32, LPWSAOVERLAPPED, u32);
fn WSAIoctl(SOCKET, u32,
    void*, u32,
    void*, u32,
    u32*,
    LPWSAOVERLAPPED, LPWSAOVERLAPPED_COMPLETION_ROUTINE) i32;


enum IOC_VENDOR = 0x18000000;
enum SIO_KEEPALIVE_VALS = IOC_IN | IOC_VENDOR | 4;

/* Argument structure for SIO_KEEPALIVE_VALS */
struct tcp_keepalive
{
    onoff: u32;
    keepalivetime: u32;
    keepaliveinterval: u32;
}
