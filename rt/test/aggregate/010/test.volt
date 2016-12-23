//T compiles:yes
//T retval:42
// Basic delegate creation.
module test;


struct Test
{
	int val;

	void setVal(int inVal)
	{
		this.val = inVal;
	}

	void addVal(int add)
	{
		val += add;
	}
}

int main()
{
	Test test;

	void delegate(int) dgt = test.setVal;
	dgt(20);

	dgt = test.addVal;
	dgt(22);

	return test.val;
}
