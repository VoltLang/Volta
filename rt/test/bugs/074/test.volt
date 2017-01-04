module test;

struct Struct
{
	x: i32;
}

global _struct: Struct;

@property fn theStruct() Struct
{
	return _struct;
}

fn main() i32
{
	theStruct.x = 15;
	return _struct.x;
}

