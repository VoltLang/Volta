//T requires:sysvamd64
module test;

extern (C) fn decode_u8_d(str: string) i32
{
	return cast(i32)str.length;
}

fn main() i32
{
	str := "hello";
	return decode_u8_d(str) - 5;
}
