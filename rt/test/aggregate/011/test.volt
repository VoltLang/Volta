//T compiles:yes
//T retval:42
// Basic class stuff.
module test;


class Parent
{
	int mField;

	this(int field)
	{
		mField = field;
		return;
	}

	int getField()
	{
		return mField;
	}
}

class Child : Parent
{
	this(int field)
	{
		super(field + 1);
		return;
	}
}

int getResult(Parent a, Parent b)
{
	return a.getField() + b.getField();
}

int main()
{
	Parent a = new Parent(20);
	return getResult(a, new Child(21));
}
