//T compiles:yes
//T retval:42
//T has-passed:no
// Basic struct write test.
module test_002;

struct Test
{
	int val;
}

int main()
{
	Test test;
	test.val = 42;
	return test.val;
}
