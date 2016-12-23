//T compiles:yes
//T retval:43
module test;

int main()
{
	int* i;
	int get()
	{
		int x = *i;
		return x;
	}
	i = new int;
	*i = 43;
	return get();
}

