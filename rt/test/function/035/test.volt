module test;

import core.varargs;

extern (C) fn printf(const(char)*, ...) i32;

fn main() i32
{
	return printf("%s\n".ptr, "ABC".ptr) - 4;
}
