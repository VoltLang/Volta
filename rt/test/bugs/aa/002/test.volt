module test;

struct Point
{
	x: i32;
	y: i32;
}

fn main() i32
{
	p: Point;
	p.x = 0;
	p.y = 0;
	aa: bool[Point];
	aa[p] = true;
	sum: i32;
	foreach (k, v; aa) {
		sum += k.x;
	}
	return sum;
}

