//T macro:import
module test;

import person;

class Child : Person
{
	global fn getNumber() i32
	{
		return Person.getAge();
	}
}

fn main(args: string[]) i32
{
	return Child.getNumber() - 12;
}
