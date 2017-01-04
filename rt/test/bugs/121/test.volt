//T default:no
//T macro:expect-failure
//T check:implicitly convert
module test;


fn main() i32
{
	foo: char[][1];
	foo[0] = "four";
	return cast(i32)foo[0].length;
}
