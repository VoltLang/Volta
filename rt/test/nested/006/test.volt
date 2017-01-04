module test;

class Person
{
	age: i32;

	this(age: i32)
	{
		this.age = age;
		return;
	}

	fn getAge() i32
	{
		fn doubleAge() i32
		{
			return age * 2;
		}
		return doubleAge();
	}
}

fn main() i32
{
	p := new Person(24);
	return p.getAge() - 48;
}
