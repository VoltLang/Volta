module test;

import core.varargs;

fn foo(x: i32 = 2, ...) i32
{
	sum: i32 = x;
	vl: va_list;
	va_start(vl);
	foreach (tid; _typeids) {
		sum += va_arg!i32(vl);
	}
	return sum;
}

fn main() i32
{
	return foo(2, 3, 4) - 9;
}
