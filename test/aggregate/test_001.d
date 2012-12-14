//T compiles:yes
//T retval:0
//T has-passed:no
// Basic struct read test.
module test_001;

struct Test
{
	int val;
}

int main()
{
	Test test;
	return test.val;
}
