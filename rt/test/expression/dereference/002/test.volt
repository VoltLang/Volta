// Test transitive dereferencing.
module test;


fn main() i32
{
	i: i32 = 21;
	const p = &i;
	return *p - 21;
}
