//T compiles:yes
//T retval:42
module test;


int main()
{
	int[4] sarr;
	// Make sure that arr refer to sarr's storage
	int[] arr = sarr;

	arr[3] = 42;

	return sarr[3];
}
