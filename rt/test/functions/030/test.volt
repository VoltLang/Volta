//T compiles:yes
//T retval:0
module test;

struct ir {
	alias Foo = i32;
}

fn foo(ir.Foo)
{
}

fn main() i32
{
	foo(32);
	return 0;
}
