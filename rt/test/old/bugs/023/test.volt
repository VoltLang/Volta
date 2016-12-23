//T compiles:yes
//T retval:42
module test;


global void function() foo;

int main()
{
	auto f = cast(typeof(foo))null;
	return 42;
}
