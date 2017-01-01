module test;

class NumberHolder
{
	i32 mNumber;

	this(number : i32)
	{
		mNumber = number;
	}
}

fn main() i32
{
	nh := new NumberHolder(0);
	return nh.mNumber;
}
