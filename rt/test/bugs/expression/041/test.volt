module test;

fn main() i32
{
	size_t x = true ? 0 : 4;
	return cast(i32) x;
}
