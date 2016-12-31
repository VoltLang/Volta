module test;

fn main() i32
{
	a := [1, 2, 3];
	b := new a[0 .. $-1];
	return (b[$-1] == 2) ? 0 : 1;
}
