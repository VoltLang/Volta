module test;


fn main() i32
{
	fn func1() {}
	global fn func2() {}

	static is (typeof(func1) == scope dg());
	static is (typeof(func2) == fn());

	return 0;
}
