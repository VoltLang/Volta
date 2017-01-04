module test;

fn main() i32
{
	a := [1, 2, 3];
	b := new a[0 .. 2];
	a[0] = 2;
	return b[0] + cast(i32)b.length - 3;
}
