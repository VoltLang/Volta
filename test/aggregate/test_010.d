//T compiles:yes
//T retval:42
//T has-passed:no
// Basic delegate creation.
module test_010;

struct Test
{
	int val;

	void setVal(int inVal)
	{
		val = inVal;
		return; /// @todo remove
	}

	void addVal(int add)
	{
		val += add;
		return; /// @todo remove
	}
}

int main()
{
	Test test;

	void delegate(int) dg = test.setVal;
	dg(20);

	dg = test.addVal;
	dg(22);

	return test.val;
}
