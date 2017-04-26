module test;

fn main() i32
{
	uB: u8 = 0xff;
	sB: i8 = cast(i8)-1;

	return
		(cast(i32)uB == 0xff) +
		(cast(u32)uB == cast(u32)0xff) +
		(cast(u32)sB == cast(u32)0xffff_ffff) - 3;
}
