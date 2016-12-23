//T compiles:no
module test;

@property fn foo(i32*)
{
}

fn main() i32
{
	p: void*;
	foo = p;
	return 0;
}

