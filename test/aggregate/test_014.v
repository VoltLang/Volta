//T compiles:yes
//T retval:42
//T has-passed:no
// Inheritance class stuff.
module test_014;

class AnotherParent
{
	int mField;

	void addToField(int val)
	{
		this.mField = mField + val;
		return;
	}
}

class Parent : AnotherParent
{
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
	Child a = new Child(20);
	a.addToField(22);
	return a.getField();
}
