module test;


global foo: fn();

fn main() i32
{
	foo = cast(typeof(foo))null;
	return 0;
}
