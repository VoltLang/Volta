module test;

struct Definition!(T)
{
	a: T;

	fn foo()
	{
		scope (success) {
			a = 12;
		}
		scope (failure) {
			a = 6;
		}
	}
}

struct Instance = mixin Definition!i32;

fn main() i32
{
	d: Instance;
	d.foo();
	return d.a - 12;
}
