//T default:no
//T macro:import
module test;


fn func(str: string) i32
{
	return cast(i32)str[5];
}

fn main() i32
{
	str: string = "Hello World";

	return func(str) - 32;
}
