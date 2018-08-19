module test;

fn main() i32
{
	if (r"aaa\aaa\aaa" != `aaa\aaa\aaa`) {
		return 1;
	}
	return 0;
}
