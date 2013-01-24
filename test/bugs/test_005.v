//T compiles:yes
//T retval:42
// Can't call functions from member functions.
module test_005;

void func()
{

}

class Test
{
	void myFunc()
	{
		// Thinks func is a member on Test.
		func();
	}
}

int main()
{
	return 42;
}
