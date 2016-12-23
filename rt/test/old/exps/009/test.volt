//T compiles:yes
//T retval:38
// Tests passing ref vars around to ref functions and non-ref functions.
module test;


void deepest(ref int i)
{
	i = 19;
	return;
}

void deep(ref int i)
{
	deepest(ref i);
	i = timesTwo(i);
	return;
}

int timesTwo(int i)
{
	return i * 2;
}

int main()
{
	int i;
	deep(ref i);
	return i;
}
