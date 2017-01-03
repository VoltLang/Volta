// Struct literals.
module test;


struct Point
{
	x: i16;
	y: i32;
}

fn main() i32
{
	p: Point = {1, 2};
	return p.x + p.y - 3;
}
