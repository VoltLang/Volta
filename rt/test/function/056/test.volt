module test;

class aClass
{
	this(ref i: i32)
	{
		i = 32;
	}
}

fn main() i32
{
	i := 64;
	auto p = new aClass(ref i);
	return i - 32;
}
