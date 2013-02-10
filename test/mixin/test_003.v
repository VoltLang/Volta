//T compiles:yes
//T retval:42
// Test mixin functions.
module test_003;

mixin function Foo()
{
	return 40;
}

int func()
{
	mixin Foo!();
}

int main()
{
	mixin("
	int i = 2;
	int g = func() + i;
	");
	return g;
}
