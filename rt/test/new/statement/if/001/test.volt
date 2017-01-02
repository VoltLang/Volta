module test;

fn main() i32
{
	b: bool = true;
	x: i32;
	v: i32*;
	if (p := b) {
		x++;
	}
	if (p := &x) {
		v = p;
		x++;
	}
	if (p := &x) {
		v = p;
		x++;
	}
	return (x == 3) ? 0 : 1;
}

