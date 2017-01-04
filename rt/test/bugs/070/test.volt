module test;

fn doubler(i: i32) i32
{
	return i * 2;
}

fn doubler(ints: i32[]...) i32
{
	sum: i32;
	foreach (i; ints) {
		sum += i * 2;
	}
	return sum;
}

fn main() i32
{
	return doubler(23) - 46;
}

