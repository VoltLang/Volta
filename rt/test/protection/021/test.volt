//T macro:importfail
//T check:tried to access protected symbol 'getAge'
module test;

import person;

class Child
{
	fn getNumber() i32
	{
		return Person.getAge();
	}
}

fn main(args: string[]) i32
{
	c := new Child();
	return c.getNumber() - 12;
}
