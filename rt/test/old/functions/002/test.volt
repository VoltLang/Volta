//T compiles:no
module test;

int mittu(ref int i)
{
}

int main()
{
	int i;
	mittu(i);
	return i;
}

