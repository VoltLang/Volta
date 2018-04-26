module main;

import core.c.errno;
import core.c.stdlib;

fn main() i32
{
	errno = 0;
	if (errno != 0) {
		return 1;
	}

	// This should set ERANGE.
	p: const(char)* = "999999999999999999999999999999999999999".ptr;
	end: char*;
	strtol(p, &end, 10);

	return errno == 0 ? 1 : 0;
}
