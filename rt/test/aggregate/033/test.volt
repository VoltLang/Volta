// Struct literals and the same hiding in arrays.
module test;

struct A
{
	x: i32;
}

fn main() i32
{
	a: A = {1};
	b: A[] = [{2}];
	c: A[][] = [[{3}, {4}]];
	return a.x + b[0].x + c[0][1].x - 7;
}

