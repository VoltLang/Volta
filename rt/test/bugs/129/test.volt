module test;


fn func(out vec: u32[2]) i32
{
	return 20;
}

fn func(out vec: u32[3]) i32
{
	return 22;
}

fn func(out vec: u32[4]) i32
{
	return 0;
}

fn main() i32
{
	v2: u32[2];
	v3: u32[3];

	// Static arrays should be able to overload properly
	return func(out v2) + func(out v3) - 42;
}
