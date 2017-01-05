module test;


fn foo() i32[]
{
	buf: i32[6];
	buf[0] = 100;

	// If buf is a dynamic array this works, so its a static array thing.
	return new buf[0 .. $];
}

fn main() i32
{
	return foo()[0] - 100;
}
