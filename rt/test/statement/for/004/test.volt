module test;

fn main() i32
{
	ptr: u8* = new u8;
	for (s := *ptr; *ptr != 0; s++) {
	}
	return *ptr;
}
