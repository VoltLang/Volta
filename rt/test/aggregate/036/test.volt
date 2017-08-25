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
	this()
	{
		// Requires at least one explicit call to super()
		// Because no implicit can be inserted at the end.
	}
}

fn main() i32
{
	b := new Base();
	return b.var + 37;
}
