module test;

alias IntPointer = i32*;

fn main() i32
{
	i: i32;
	p := &i;
	p = IntPointer.init;
	return cast(i32)p;
}
