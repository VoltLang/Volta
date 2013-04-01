//T compiles:yes
//T retval:42
//T has-passed:no
module test_023;

global void function() foo;

int main()
{
	auto f = cast(typeof(foo))null;
	return 42;
}
