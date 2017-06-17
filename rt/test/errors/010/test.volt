//T default:no
//T macro:expect-failure
//T check:cannot cast aggregate
module test;

struct S
{
	i: i32;
}

fn main() i32
{
	s: S;
	s.i = 42;
	i := cast(i32)s;
	return i - 42;
}
