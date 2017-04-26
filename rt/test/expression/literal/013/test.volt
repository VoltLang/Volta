module test;

fn main() i32
{
	if (0xFFFF_FFFF_i32 != -1) {
		return 1;
	}
	if (0xFF_i8 != -1) {
		return 3;
	}
	return 0;
}
