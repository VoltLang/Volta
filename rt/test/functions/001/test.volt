//T compiles:yes
//T retval:17
module test;

void hitotu(out int i)
{
	i = 15;
}

void futatu(ref int i)
{
	i += 2;
}

int main()
{
	int i;
	hitotu(out i);
	futatu(ref i);
	return i;
}

