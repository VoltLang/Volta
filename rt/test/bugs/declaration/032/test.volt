module test;


fn main() i32
{
	foo: const(char)[][1];
	foo[0] = "four";
	return cast(i32)foo[0].length - 4;
}
