// null not handled to constructors.
module test;


class Clazz
{
	this(t: string)
	{
	}
}

fn main() i32
{
	c := new Clazz(null);
	return 0;
}
