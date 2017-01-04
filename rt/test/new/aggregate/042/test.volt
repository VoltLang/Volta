//T default:no
//T macro:expect-failure
//T check:structs or unions may not define default constructors
module test;

struct Struct
{
	this()
	{
	}
}

fn main() i32
{
	return 0;
}
