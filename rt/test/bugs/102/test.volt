module test;

class Sum
{
	value: i32;

	this(integers: i32[]...)
	{
		foreach (integer; integers) {
			value += integer;
		}
	}
}

fn main() i32
{
	sum := new Sum(7);
	return sum.value - 7;
}

