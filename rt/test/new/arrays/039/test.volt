module test;

fn main() i32
{
	a := [1, 2, 3];
	b := a[..];
	return (b[$-1] == 3) ? 0 : 1;
}
