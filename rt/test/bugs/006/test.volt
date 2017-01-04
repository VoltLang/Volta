// Implicit conversions doesn't work for binops.
module test;


fn main() i32
{
	t: size_t = 1;
	arr := new i32[](4);
	arr[0 .. t + 1];

	str := new char[](1);
	str[0] = 20;

	return 0;
}
