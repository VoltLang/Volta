//T default:no
//T macro:expect-failure
// Test that assigning null to AAs is an error.
module test;

fn main() i32
{
	result: i32 = 42;
	aa := [3:result];
	aa := null;
	return aa[3];
}
