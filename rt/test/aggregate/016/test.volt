// Generic function calling tests.
module test;

struct Struct
{
	g: i32;

	fn func() i32
	{
		return g;
	}
}

class Clazz
{
	this()
	{
	}

	g: i32;

	fn func() i32
	{
		return g;
	}
}

fn main() i32
{
	s: Struct;
	c := new Clazz();
	dg1 := s.func;
	dg2 := c.func;

	c.g = 6;
	s.g = 15;

	return (c.func() + s.func() + dg1() + dg2()) - 42;
}
