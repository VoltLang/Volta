//T compiles:yes
//T retval:30
// A small exercise of ref.
module test;


void addOne(ref int i)
{
	int base = i;
	i = base + 1;
	return;
}

int main()
{
	int i = 29;
	addOne(ref i);
	return i;
}
