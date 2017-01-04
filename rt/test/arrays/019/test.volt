//T default:no
//T macro:expect-failure
// Test appending to an array, expected to fail.
module test;


fn main() i32
{
	s: f32[];
	i: f64 = 3.0;
	s ~= i;
	return 0;
}
