//T default:no
//T macro:expect-failure
// Assigning to invalid value type.
module test;

fn main() i32
{
	aa: i32[i32];
	x: string = aa["volt"];
	return 1;
}
