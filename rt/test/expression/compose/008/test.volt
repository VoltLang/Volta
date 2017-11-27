module test;

fn main() i32
{
	val := new "${ \"a\" }";
	return val == "a" ? 0 : 1;
}