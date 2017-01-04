// Anon base typed enum.
module test;


enum : u32
{
	FOO = 5,
}

fn main() i32
{
	if (typeid(typeof(FOO)) is typeid(u32))
		return 0;
	return 42;
}
