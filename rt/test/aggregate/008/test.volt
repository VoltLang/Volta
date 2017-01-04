//T default:no
//T macro:expect-failure
// Struct literals.
module test;


struct Point
{
	x: i16;
	y: i32;
}

fn getY(p: Point) i32
{
	return p.y;
}

fn main() i32
{
	// Struct literals in function calls not supported.
	return 1 + getY({1, 2});
}
