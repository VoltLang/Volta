//T compiles:no
module test;

int foo(int[2] a)
{
	return a[0] + a[1];
}

int foo(string s)
{
	return cast(int) s.length;
}

int main()
{
	return foo([19, 8, 6]);
}
