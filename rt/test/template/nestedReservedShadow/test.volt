//T macro:expect-failure
//T check:shadows
module main;

struct Test!(T)
{
	fn foo()
	{
		T: i32;
	}
}

struct TheInstance = mixin Test!i32;

fn main() i32
{
	return 0;
}
