//T compiles:yes
//T retval:3
module test;

fn getThree(i32) i32
{
	return 3;
}

fn main() i32
{
	return getThree(17);
}
