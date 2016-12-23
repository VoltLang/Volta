//T compiles:no
module test;

global scope int* x;

int main()
{
	scope int* y = null;
	x = y;
	return 0;
}

