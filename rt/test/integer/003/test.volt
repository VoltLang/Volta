//T macro:expect-failure
module test;


fn main() i32
{
	byteVar: i8;
	uintVar: u32;

	// mixing signed ness.
	var := byteVar + uintVar;
	return 0;
}

