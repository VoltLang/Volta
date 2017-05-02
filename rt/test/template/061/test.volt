module test;

struct S!(val: i32)
{
	enum E = val + 1;
}

struct SS = mixin S!32;

fn main() i32
{
	return SS.E - 33;
}
