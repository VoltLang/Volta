// More function calling tests.
module test;


fn outerFunc() i32
{
	return 2;
}

struct Struct
{
	g: i32;

	fn other() i32
	{
		return 1;
	}

	fn func() i32
	{
		return g + other() + outerFunc();
	}
}

class Clazz
{
	this()
	{
	}

	g: i32;

	fn other() i32
	{
		return 1;
	}

	fn func() i32
	{
		return g + other() + outerFunc();
	}
}

fn main() i32
{
	s: Struct;
	c := new Clazz();
	dg1 := s.func;
	dg2 := c.func;

	c.g = 3;
	s.g = 12;

	return (c.func() + s.func() + dg1() + dg2()) - 42;
}
