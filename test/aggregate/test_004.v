//T compiles:yes
//T retval:0
// Basic struct function passing test.

module test_004;

struct Test
{
	int val;
	int otherVal;
}

int func(Test t)
{
	return t.otherVal;
}

int main()
{
	Test test;
	test.val = 42;
	return func(test);
}
