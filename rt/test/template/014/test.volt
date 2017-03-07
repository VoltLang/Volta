module test;

struct Zero
{
	x: i32;
}

struct Definition!(T)
{
	a: T;

	fn foo() T
	{
		zero: Zero;
		with (zero) {
			return x;
		}
	}
}

struct Instance = mixin Definition!i32;

fn main() i32
{
	d: Instance;
	return d.foo();
}
