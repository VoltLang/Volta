module test;

fn aNumber(n: i32 = i32.max) i32
{
	return n;
}

fn main() i32
{
	if (aNumber() == i32.max) {
		return 0;
	}
	return 3;
}

