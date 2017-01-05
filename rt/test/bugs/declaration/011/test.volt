module test;

alias foo = i32;

fn main() i32
{
	return cast(i32) typeid(foo).size - 4;
}

