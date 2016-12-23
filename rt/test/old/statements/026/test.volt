//T compiles:yes
//T retval:exception
module test;

fn foo()
{
	assert(false);
}

fn main() i32
{
	foo();
	return 0;
}
