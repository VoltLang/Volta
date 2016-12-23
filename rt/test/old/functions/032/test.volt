//T compiles:yes
//T retval:53
module test;

import core.varargs;
import core.typeinfo;

fn sum(...) f64
{
	va_list vl;

	va_start(vl);
	f64 result;
	foreach (tid; _typeids) {
		if (tid.type == Type.F64) {
			result += va_arg!f64(vl) * 2;
		} else if (tid.type == Type.F32) {
			result += va_arg!f32(vl);
		} else {
			assert(false);
		}
	}
	va_end(vl);

	return result;
}

fn main() i32
{
	return cast(int)sum(1.0f, 1.0, 10.0f, 20.0);
}
