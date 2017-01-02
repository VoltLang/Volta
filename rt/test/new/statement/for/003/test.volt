module test;

fn main() i32
{
	for (i: u32; i < 4; i++) {
	}
	for (i: u32 = 2; i < 4; i++) {
		return cast(i32)i - 2;
	}
	return 2;
}
