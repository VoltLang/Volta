//T macro:expect-failure
module test;

interface Wow
{
	fn doge();
}

class Such : Wow
{
	fn doge() i32
	{
		return 42;
	}
}

fn main() i32
{
	return (new Such()).doge();
}

