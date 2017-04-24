//T has-passed:no
module test;

// Minimal testing of compile time evaluation of expressions.
enum Bits = typeid(i32).size * 8;

fn main() i32
{
	return Bits != 32 ? 1 : 0;
}
