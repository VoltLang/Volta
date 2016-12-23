//T compiles:yes
//T retval:42
module test;


int main()
{
	void func1() {}
	global void func2() {}

	static is (typeof(func1) == scope void delegate());
	static is (typeof(func2) == void function());

	return 42;
}
