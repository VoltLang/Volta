//T compiles:yes
//T retval:3
module test;

int main()
{
	int[2] x;
	int a = 1, b = 2;
	x = [a, b];
	return x[0] + x[1];
}

