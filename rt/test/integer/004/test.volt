module test;


fn main() i32
{
	ubyteVar: u8 = 4;
	uintVar: u32 = 1;

	uintVar = uintVar << ubyteVar;
	uintVar = uintVar >> 2;

	return cast(i32)uintVar == 4 ? 0 : 1;
}

