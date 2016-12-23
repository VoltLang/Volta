//T compiles:yes
//T retval:3
module test;

struct Point2D
{
	x : f32;
	y : f32;
	a, b : i32;
}

fn main() i32
{
	Point2D p;
	p.x = 3.2f;
	p.b = cast(i32)p.x;
	return p.b;
}
