module test;

class aClass
{
	i: i32;
	b: bool;

	this(integer: i32, boolean: bool)
	{
		i = integer;
		b = boolean;
	}
}

fn main() i32
{
	p := new aClass(integer:32, boolean:true);
	return p.b ? p.i - 32 : 1;
}
