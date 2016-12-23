//T compiles:yes
//T retval:42
module test;


global void function() foo;

int main()
{
	foo = null;
	return 42;
}
