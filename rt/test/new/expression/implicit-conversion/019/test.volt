// Test converting int implicitly to float.
module test;


fn main() i32
{
	a: i32 = 42;
	b: f32;
	c: f32 = b + a;
	return cast(i32)c - 42;
}
