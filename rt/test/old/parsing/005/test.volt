//T compiles:yes
//T retval:3
module test;

fn foo(...) i32
{
	return 3;
}

fn main() i32
{
	return foo();
}
