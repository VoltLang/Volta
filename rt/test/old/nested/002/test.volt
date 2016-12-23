//T compiles:yes
//T retval:48
module test;

class Person
{
	int age;

	this(int age)
	{
		this.age = age;
		return;
	}

	int getAge()
	{
		int doubleAge()
		{
			return age * 2;
		}
		return doubleAge();
	}
}

int main()
{
	auto p = new Person(24);
	return p.getAge();
}
