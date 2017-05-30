module test;

struct A!(T, PI: i32)
{
	x: T;

	fn muddle()
	{
		x += PI;
	}
}

struct B!(T)
{
	z: T;
}

struct C = mixin A!(i32, 3);
struct D = mixin B!C;

fn halve(ref c: C)
{
	c.x = c.x / 2;
}

fn main() i32
{
	d: D;
	d.z.x = 32;
	halve(ref d.z);
	d.z.muddle();
	return d.z.x - 19;
}
