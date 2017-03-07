module test;

import core.varargs;

struct Foo!(T)
{
	fn sum(...) T
	{
		vl: va_list;
		sum: T;
		va_start(vl);
		sum += va_arg!T(vl);
		va_end(vl);
		return sum;
	}
}

struct Instance = mixin Foo!(i32);
struct Instance2 = mixin Foo!(f32);

fn main() i32
{
	d: Instance;
	return d.sum(0);
}
