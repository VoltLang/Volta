module test;

fn main() i32
{
	a := [1, 2, 3];
	b := new a[..];
	a[1] = 30;
	return (b[0] + b[1] + b[2] == 6) ? 0 : 1;
}

