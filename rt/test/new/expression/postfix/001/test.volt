module test;

struct OtherStruct
{
	fn x() i32 { return 7; }
}

struct S
{
	os: OtherStruct;

	@property fn someFunction() OtherStruct
	{
		return os;
	}

	@property fn y() i32 { return 3; }


	fn proxy() i32
	{
		return someFunction.x() + y;
	}
}

fn main() i32
{
	instance: S;
	return instance.proxy() - 10;
}
