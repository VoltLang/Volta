//T compiles:yes
//T retval:42
module test;


int main()
{
	immutable int foo;

	typeof(foo + 4) i1;
	typeof(4 + foo) i2;

	i1 = 20;
	i2 = 22;

	return i1 + i2;
}
