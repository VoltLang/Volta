// Tests New Lowering
module test;


fn main() i32
{
	ip: i32* = new i32;
	*ip = 7;
	return *ip == 7 ? 0 : 1;
}

