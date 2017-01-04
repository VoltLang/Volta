// More AA initialiser tests.
module test;

fn main() i32
{
	result: i32 = 42;
	aa := [3:result];
	return aa[3] == 42 ? 0 : 1;
}
