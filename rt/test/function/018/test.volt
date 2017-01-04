module test;

class Person
{
	this(name: string)
	{
		mName = name;
	}

	@property fn name() string
	{
		return mName;
	}

	private mName: string;
}

fn main() i32
{
	p := new Person("mud");
	return p.name == "mud" ? 0 : 1;
}
