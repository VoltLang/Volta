//T default:no
//T macro:expect-failure
//T check:2 overloaded functions match call
module test;

class S
{
	x: i32;

	this(y: i32=0)
	{
		x = y;
	}

	this()
	{
		x = 34;
	}
}

fn main(args: string[]) i32
{
	S s = new S();
	return s.x;
}
