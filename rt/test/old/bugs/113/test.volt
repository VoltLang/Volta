//T compiles:yes
//T retval:10
module test;


int over(int[] foo)
{
	return foo[0];
}

int func(int* ptr, size_t len)
{
	return 42;
}

alias func = over;

int main()
{
	int[1] arr;
	arr[0] = 10;

	return func(arr);
}
