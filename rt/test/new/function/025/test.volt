module test;

class LoadedDice
{
	num: i32;

	this(n: i32 = 2)
	{
		num = n;
	}
}

fn main() i32
{
	dice := new LoadedDice();
	return dice.num - 2;
}
