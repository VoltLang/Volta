module test;

fn setA(ref a : i32) void
{
	a = 2;
}

fn setB(out b : i32) void
{
	b = 4;
}

i32 main()
{
	c, d: i32;
	setA(ref c);
	setB(out d);
	return (c + d) - 6;
}
