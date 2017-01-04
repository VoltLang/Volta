//T default:no
//T macro:expect-failure
// Test appending to an array, expected to fail.
module test;


fn main() i32
{
	s: u32[];
	i: i32 = 3;
	s ~= i;
	return 0;
}

