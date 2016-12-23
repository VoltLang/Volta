//T compiles:yes
//T retval:2
module test;

class LoadedDice
{
	i32 num;

	this(n : i32 = 2)
	{
		num = n;
	}
}

fn main() i32
{
	dice := new LoadedDice();
	return dice.num;
}
