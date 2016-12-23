//T compiles:yes
//T retval:42
// Basic this stuff.
module test;


class First
{
	int mField;

	this(int field)
	{
		this.mField = field;
		return;
	}

	int getField()
	{
		return this.mField;
	}
}

int main()
{
	First a = new First(42);

	return a.getField();
}
