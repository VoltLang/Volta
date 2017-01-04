// @property functions.
module test;


struct S
{
	@property fn foo() i32
	{
		return 7;
	}

	@property fn bar(x: i32) i32
	{
		return x * 2;
	}
}

fn main() i32
{
	s: S;
	return (s.bar = s.foo) - 14;
}
