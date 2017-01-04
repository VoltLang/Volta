module test;

fn main() i32
{
	ints: i32[];
	fn countToTen() i32
	{
		ints ~= countToTen();
		return 4;
	}
	return 0;
}

