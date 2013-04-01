//T compiles:yes
//T retval:42
// @loadDynamic test.
module test_005;


int func(int val)
{
	return 21 + val;
}

@loadDynamic int foo(int);

int main()
{
	foo = func;
	return foo(21);
}
