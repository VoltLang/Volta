// Passing pointer TypeReferences.
module test;


struct Struct
{
	t: i32;
}

union Union
{
	t: i32;
}

fn func(Struct*, Union*)
{
	return;
}

fn main() i32
{
	s: Struct;
	u: Union*;
	func(&s, u);

	return 0;
}
