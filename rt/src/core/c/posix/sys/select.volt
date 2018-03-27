module core.c.posix.sys.select;

version (Posix):
extern (C):

import core.c.config : c_long;
import core.c.posix.sys.time : timeval;

private enum FD_SETSIZE = 1024;
private enum NFDBITS = 8 * cast(i32)typeid(fd_mask).size;

version (OSX) {
	alias fd_mask = i32;
} else {
	alias fd_mask = c_long;
}

struct fd_set
{
	fds_bits: fd_mask[FD_SETSIZE / NFDBITS];
}

private fn FD_ELT(d: i32) i32
{
	return d / NFDBITS;
}

private fn FD_MASK(d: i32) fd_mask
{
	return cast(fd_mask)(1 << (d % NFDBITS));
}

fn FD_ZERO(set: fd_set*)
{
	for (i: u32 = 0; i < typeid(fd_set).size / typeid(fd_mask).size; ++i) {
		set.fds_bits[i] = 0;
	}
}

fn FD_SET(fd: i32, set: fd_set*)
{
	set.fds_bits[FD_ELT(fd)] |= FD_MASK(fd);
}

fn FD_CLR(fd: i32, set: fd_set*)
{
	set.fds_bits[FD_ELT(fd)] &= ~FD_MASK(fd);
}

fn FD_ISSET(fd: i32, set: fd_set*) i32
{
	return (set.fds_bits[FD_ELT(fd)] & FD_MASK(fd)) != 0;
}

fn select(i32, fd_set*, fd_set*, fd_set*, timeval*) i32;

