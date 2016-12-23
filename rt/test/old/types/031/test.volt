//T compiles:yes
//T retval:3
module test;

global scope int* x;

void foo(scope int* z)
{
	return;
}

int main()
{
	scope int* y = x;
	foo(x);
	return 3;
}

