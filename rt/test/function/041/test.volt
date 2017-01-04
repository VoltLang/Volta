//T default:no
//T macro:expect-failure
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

