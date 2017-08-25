//T macro:expect-failure
module test;


fn main() i32
{
	static is(i32 == i32);
	static is(i32 == char[]);
}
