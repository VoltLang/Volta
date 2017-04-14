module test;

struct Definition!(T)
{
	field: T;

	fn plusOne(val: T) T
	{
		return val + 1;
	}

	fn plusOne(d: Definition) T
	{
		return plusOne(d.field);
	}
}

struct Instance = mixin Definition!i32;
struct Instance2 = mixin Definition!f32;

fn main() i32
{
	a, b: Instance;
	a.field = -1;
	return b.plusOne(a);
}
