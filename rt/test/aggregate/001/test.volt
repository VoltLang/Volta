//T compiles:yes
//T retval:0
// Basic struct read test.
module test;


struct Test
{
	int val;
}

int main()
{
	Test test;
	return test.val;
}
