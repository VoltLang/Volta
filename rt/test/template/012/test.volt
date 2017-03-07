module test;

struct Definition!(T)
{
	a: T;

	fn foo() T in {
		assert(true);
	} out (result) {
		assert(result == 0);
	} body {
		return 0;
	}
}

struct Instance = mixin Definition!i32;

fn main() i32
{
	d: Instance;
	return d.foo();
}
