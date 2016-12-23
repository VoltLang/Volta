//T compiles:no
module test;

class A {}

void foo(A*[] foo)
{
}

int main()
{
	const(A)*[] a;
	foo(a);
	return 0;
}

