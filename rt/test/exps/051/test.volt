//T compiles:yes
//T retval:3
module test;

int main()
{
	int[2] x;
	x = [1, 2];
	return x[0] + x[1];
}

