// Test that enums can be implicitly casted to their base.
module test;


enum named { a, b, c, }

fn main() i32
{
	return named.a;
}
