module test;

class Parent
{
	fn b() i32
	{
		return 423;
	}

	fn c() i32
	{
		return b();
	}
}

class Class : Parent
{
	base: i32;

	fn a() i32
	{
		return base;
	}

	final override fn b() i32
	{
		return base;
	}
}

class Child : Class
{
	override fn a() i32
	{
		return base * 2;
	}
}

fn main() i32
{
	c: Class = new Child();
	c.base = 6;
	c.base = c.c();
	return c.b() - (c.a() / 2);
}
