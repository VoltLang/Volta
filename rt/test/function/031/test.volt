module test;

import core.varargs;
import core.typeinfo;

fn sum(...) i32
{
	vl: va_list;

	va_start(vl);
	result: i32;
	foreach (tid; _typeids) {
		if (tid.type == Type.I32) {
			result += va_arg!i32(vl);
		} else if (tid.type == Type.I16) {
			result += va_arg!i16(vl);
		} else if (tid.type == Type.I8) {
			result += va_arg!i8(vl);
		} else {
			assert(false);
		}
	}
	va_end(vl);

	return result;
}

fn main() i32
{
	a: i32 = -2;
	b: i16 = 1;
	c: i32 = 10;
	d: i8 = 1;
	return sum(b, c, d, a) - 10;
}
