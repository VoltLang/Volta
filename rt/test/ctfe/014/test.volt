module test;

fn accumulate(x: i32) i32
{
	if (x == 10) {
		return x;
	}
	return accumulate(x + 1);
}

fn ten() i32
{
	return accumulate(0) - 10;
}

fn main() i32
{
	return #run ten();
}

