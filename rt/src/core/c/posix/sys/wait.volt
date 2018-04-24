module core.c.posix.sys.wait;

version (Posix):
extern (C):

fn WEXITSTATUS(rv: i32) i32
{
	return (rv >> 8) & 0xFF;
}
