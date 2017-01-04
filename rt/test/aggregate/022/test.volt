//T default:no
//T macro:expect-failure
// Test that named enums can not be explicitly typed.
module test;


enum named { a: i32; }

fn main() i32
{
	return named.a;
}
