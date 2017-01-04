//T default:no
//T macro:expect-failure
//T check:cannot implicitly convert
// Ensure that immutable can't become mutable through const.
module test;


fn bar(char[])
{
}

fn foo(a: const(char[]))
{
	bar(a);
}

fn main() i32
{
	str: immutable(char[]);
	foo(str);
	return 0;
}
