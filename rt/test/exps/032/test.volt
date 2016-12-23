//T compiles:yes
//T retval:42
module test;

int main()
{
	int val21 = 21;
	int val20 = --val21;
	val21 = ++val20;

	return val21 + val20;
}
