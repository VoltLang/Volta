//T compiles:no
module test;

int main()
{
	int[2] x;
	x = [1, 2, 3];
	return x[0] + x[1];
}

