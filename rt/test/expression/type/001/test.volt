module test;

alias IntArray = i32[];

fn main() i32
{
	y := [1, 2, 3];
	y = IntArray.init;
	return cast(i32)y.length;
}
