//T compiles:yes
//T retval:42
// Simple annotation test.
module test_001;


int main()
{
	auto f1 = __traits(getAttribute, func, Foo);
	auto f2 = __traits(getAttribute, var, Foo);


	return f1.value + f2.value;
}

@Foo(20) void func() { return; }
@Foo(22) global int var;

@interface Foo
{
	int value;
}
