module test;

fn foo(const(i32**)*)
{
	return;
}

fn bar(arg: const(i32*)**)
{
	foo(arg);
}

fn main() i32
{
	return 0;
}

