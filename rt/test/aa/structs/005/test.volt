module test;

struct Point
{
	x, y: i32;
}

fn main() i32
{
	p: Point;
	p.x = 12;
	p.y = 24;
	aa: bool[Point];
	aa[p] = true;
	assert((p in aa) !is null);
	assert(aa.keys[0].x == 12);
	assert(aa.keys[0].y == 24);
	return 0;
}
