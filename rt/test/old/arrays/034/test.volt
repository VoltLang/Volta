//T compiles:yes
//T retval:16
module test;


int main()
{
	int[4] foo;
	auto f = cast(void[])foo;
	return cast(int) f.length; // 4 * 4 = 16
}
