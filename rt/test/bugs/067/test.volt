//T compiles:yes
//T retval:7
module test;

int bar(int[] x)
{
	return x[0];
}

int foo(out int[] x)
{
	x = [7];
	return bar(x);
}

int main()
{
	int[] x;
	return foo(out x);
}
