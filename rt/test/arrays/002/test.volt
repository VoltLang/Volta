//T compiles:yes
//T retval:42
// Test string literals.
module test;


int func(int[] val)
{
	return val[1];
}

int main()
{
	return func([41, 42, 43]);
}
