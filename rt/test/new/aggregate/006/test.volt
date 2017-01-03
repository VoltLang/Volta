// Making sure that local/global variables don't change struct layout.
module test;


struct Source
{
	pad: i32;
	local localVal: i32;
	val: i32;
}

struct Dest
{
	pad: i32;
	val: i32;
}

fn main() i32
{
	src: Source;
	dst: Dest;

	src.val = 42;
	dst = *cast(Dest*)&src;

	return dst.val - 42;
}
