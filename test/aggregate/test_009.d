//T compiles:yes
//T retval:42
//T has-passed:no
// Basic function call & this test.
module test_009;

struct Test
{
	int val;

	void setVal(int inVal)
	{
		val = inVal;
		return; /// @todo remove
	}
}

int main()
{
	Test test;
	test.setVal(42);
	return test.val;
}
