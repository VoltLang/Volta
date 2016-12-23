//T compiles:yes
//T retval:12
module test;

class Person
{
	this(string name)
	{
		mName = name;
	}

	@property fn name() string
	{
		return mName;
	}

	private string mName;
}

fn main() i32
{
	auto p = new Person("mud");
	return p.name == "mud" ? 12 : 1;
}
