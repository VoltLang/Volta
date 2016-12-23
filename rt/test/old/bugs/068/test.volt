//T compiles:yes
//T retval:12
module test;

class Parent
{
	int contemplate()
	{
		return 7;
	}
}

class Child : Parent
{
	int contemplate(int ignored)
	{
		return 12;
	}
}

int main()
{
	auto child = new Child();
	return child.contemplate(17);
}

