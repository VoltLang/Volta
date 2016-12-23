//T compiles:yes
//T retval:2
module test;

fn setToTwo(ref x : i32)
{
	x = 2;
}

fn main() i32
{
	too : i32;
	setToTwo(ref too);
	return too;
}
