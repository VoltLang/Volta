//T default:no
//T macro:expect-failure
//T check:cannot implicitly convert
// Test implicit conversion from const doesn't allow invalid conversions to occur.
module test;


fn foo(i: i16)
{
	return;
}

fn main() i32
{
	i: const(i32);
	foo(i);
	return 42;
}
