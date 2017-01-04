//Simple static array test.
module test;


fn main() i32
{
	arg: i32[4];
	arg[0] = 42;

	return (arg[0] == 42) ? 0 : 1;
}
