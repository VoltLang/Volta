module test;

fn main() i32
{
	a, b: u32;
	a = 0x8000_0000U;
	b = a >> 1U;
	if (b == 0x4000_0000) {
		return 0;
	} else {
		return 17;
	}
}

