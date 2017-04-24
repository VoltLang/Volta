module test;

// Minimal testing of compile time evaluation of expressions.
enum Foo = 4;
enum Bar = Foo + 5;
enum Fizz = Bar / 2;

fn main() i32
{
	return Fizz != 4 ? 1 : 0;
}
