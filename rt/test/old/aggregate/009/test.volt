//T compiles:yes
//T retval:42
// Basic function call & this test.
module test;


struct Test
{
	int val;

	void setVal(int inVal)
	{
		val = inVal;
	}
}

int main()
{
	Test test;
	test.setVal(42);
	return test.val;
}
