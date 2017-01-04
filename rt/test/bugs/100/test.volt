//T default:no
//T macro:expect-failure
//T check:implicitly convert
module test;

class A {}

fn foo(f: A*[])
{
}

fn main() i32
{
	a: const(A)*[];
	foo(a);
	return 0;
}

