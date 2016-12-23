//T compiles:yes
//T retval:1
module test;

void addOne(out int x)
{
	// x is initialized to zero.
	x++;
}

int main()
{
	int x = 22;
	addOne(out x);
	return x;
}

