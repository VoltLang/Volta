module test;

union u
{
	a: u32;
	b: u32;
}

fn main() i32
{
	return cast(i32)typeid(u).size - 4;
}

