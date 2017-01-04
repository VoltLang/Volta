//T default:no
//T macro:expect-failure
//T check:cannot implicitly convert
module test;


enum Foo : i32 {
	v1 = 0xffffffff,
	v2 = 0x1ffffffff, // Error can't fit long into int.
}

fn main() i32
{
	return 0;
}
