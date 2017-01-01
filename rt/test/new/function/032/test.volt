module test;

import core.varargs;
import core.typeinfo;

fn sum(...) f64
{
	vl: va_list;

	va_start(vl);
	result: f64;
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
	return cast(i32)sum(1.0f, 1.0, 10.0f, 20.0) - 53;
}
