//T compiles:yes
//T retval:42
//Simple static array test.
module test;


int main()
{
	int[4] arg;
	arg[0] = 18;
	arg[1] = 16;

	auto arr = arg[];
	auto ptr = arg.ptr;

	return arr[0] + ptr[1] + cast(int)arg.length + cast(int)arr.length;
}
