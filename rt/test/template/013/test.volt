module test;

struct Definition!(T)
{
	a: T;

	fn foo(v: T) T
	{
		switch (v) {
		case 3:
			goto case 7;
		case 7:
			return 0;
		default: return 5;
		}
	}
}

struct Instance = mixin Definition!i32;

fn main() i32
{
	d: Instance;
	return d.foo(3);
}
