module test;

fn main() i32
{
	a: i32[][] = [[1, 2, 3]];
	b: i32[][] = [[0, 0, 0]];
	b[0] = new a[0][0 .. $];
	return  (b[0][1] == 2) ? 0 : 1;
}
