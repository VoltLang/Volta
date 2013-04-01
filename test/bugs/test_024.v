//T compiles:yes
//T retval:42
//T has-passed:no
module test_024;

global void function() foo;

int main()
{
	foo = null;
	return 42;
}
