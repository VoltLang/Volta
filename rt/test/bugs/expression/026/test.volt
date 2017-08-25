//T macro:expect-failure
//T check:implicitly convert
module test;

import core.object;

class Derived
{
}

fn count(objects: Object[]...) i32
{
	return cast(i32) objects.length; 
}

fn main() i32
{
	return count([new Derived()]);
}
