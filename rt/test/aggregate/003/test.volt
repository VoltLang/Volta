//T compiles:yes
//T retval:42
// Basic struct function passing test.
module test;


struct Test
{
	int val;
}

int func(Test t)
{
	return t.val;
}

int main()
{
	Test test;
	test.val = 42;
	return func(test);
}
