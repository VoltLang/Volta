//T compiles:yes
//T retval:42
// Inheritance class stuff.
module test_013;

class Parent
{
	int mField;
}

class Child : Parent
{
	this(int field)
	{
		mField = field;
		return;
	}

	int getField()
	{
		return this.mField;
	}
}

int main()
{
	Child a = new Child(42);

	return a.getField();
}
