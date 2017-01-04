module test;

fn foo(const(ubyte)**)
{
	return;
}

fn main() i32
{
	data: ubyte**;
	foo(data);
	return 0;
}

