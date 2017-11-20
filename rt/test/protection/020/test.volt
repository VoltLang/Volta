//T macro:import
module test;

import person;

class Child : Person
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
