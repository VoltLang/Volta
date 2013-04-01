//T compiles:yes
//T retval:42
module test_022;

global void function() foo;

int main()
{
	foo = cast(typeof(foo))null;
	return 42;
}
