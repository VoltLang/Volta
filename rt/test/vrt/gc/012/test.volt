module test;

struct ShouldBeEightBytes
{
	a: i32;
	b: i16;
}

fn main() i32
{
	if (typeid(ShouldBeEightBytes).size != 8) {
		return 1;
	}
	return 0;
}

