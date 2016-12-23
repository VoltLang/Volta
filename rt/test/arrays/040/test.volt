//T compiles:yes
//T retval:3
module test;

struct A {
	int[] a;
}

int main()
{
	A a, b;
	a.a = [1, 2, 3];
	b.a = new a.a[..];
	return b.a[$-1];
}
