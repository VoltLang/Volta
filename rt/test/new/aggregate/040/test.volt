module test;

struct Point2D
{
	x: f32;
	y: f32;
	a, b: i32;
}

fn main() i32
{
	p: Point2D;
	p.x = 3.2f;
	p.b = cast(i32)p.x;
	return p.b - 3;
}
