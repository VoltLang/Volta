//T compiles:yes
//T retval:4
module test;

class C
{
	int foo(int[] a...)
	{
		return a[0] + a[1];
	}
}

int main()
{
	auto c = new C();
	return c.foo(3, 1);
}
