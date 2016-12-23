//T compiles:yes
//T retval:10
module test;

import core.varargs;
import core.typeinfo;

fn sum(...) i32
{
	va_list vl;

	va_start(vl);
	i32 result;
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
	i32 a = 0xFFFFFFFE;
	i16 b = 1;
	i32 c = 10;
	i8 d = 1;
	return sum(b, c, d, a);
}
