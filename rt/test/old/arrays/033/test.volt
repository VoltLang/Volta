//T compiles:yes
//T retval:16
module test;


int main()
{
	int[] foo = new int[](4);
	auto f = cast(void[])foo;
	return cast(int) f.length; // 4 * 4 = 16
}
