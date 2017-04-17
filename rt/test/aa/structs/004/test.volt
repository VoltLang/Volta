//T has-passed:no
module test;

struct Point
{
	x: i32;
	y: i32;
	z: i32;
	xx: i32;
}

fn main() i32
{
	x: i32 = 12;
	p: Point;
	p.x = 3;
	aa: Point[Point];
	aa[p] = p;
	p.x = 7;
	aa[p] = p;
	sum: i32;
	aa2: string[i32];
	aa2[12] = "hello";
	foreach (k, v; aa) {
		sum += k.x;
	}
	foreach (k, v; aa2) {
		sum += k;
	}
	return sum == 22 ? 0 : sum;
}

