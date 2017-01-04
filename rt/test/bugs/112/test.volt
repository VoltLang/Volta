module test;


class Clazz
{

}

struct My
{
	foo: i32;
	ptr: i32*;
	arr: i32[];
	dgt: dg();
	func: fn();
	clazz: Clazz;
}

fn main() i32
{
	my: My;
	my.foo = 42;
	my = My.init;

	return my.foo;
}
