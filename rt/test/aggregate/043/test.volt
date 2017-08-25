//T macro:expect-failure
//T check:structs or unions may not define a destructor
module test;

struct Struct
{
	~this()
	{
	}
}

fn main() i32
{
	return 0;
}
