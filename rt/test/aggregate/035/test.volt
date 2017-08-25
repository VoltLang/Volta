//T macro:expect-failure
//T check:expected explicit super call
module test;


class Super
{
public:
	var: i32;

public:
	this(i32)
	{
		this.var = 5;
	}
}

class Base : Super
{
	// Need a explicit this because no default can be generated.
}

fn main() i32
{
	b := new Base();
	return b.var + 37;
}
