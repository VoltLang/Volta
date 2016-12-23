//T compiles:yes
//T retval:42
module test;

void addOne(ref int i)
{
	i += 1;
}

void set(out int i, int N)
{
	i = N;
}

int main()
{
	int x;
	x.set(41);
	x.addOne();
	return x;
}

