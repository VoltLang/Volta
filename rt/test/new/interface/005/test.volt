module test;

interface Wow
{
	fn doge() i32;
}

union Union
{
	foo: i32;
	bar: size_t;
}

class Such : Wow
{
	bad: Union;

	override fn doge() i32
	{
		return 0;
	}
}

fn much(wow: Wow) i32
{
	return wow.doge();
}

fn main() i32
{
	return much(new Such());
}

