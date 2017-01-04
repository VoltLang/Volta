module test;


fn main() i32
{
	if (is(const(i32) == const(i32))) {
		return 0;
	} else {
		return 2;
	}
}
