//T compiles:yes
//T retval:4
module test;

extern(C) fn printf(const(char)*, ...) int;


int main()
{
	printf("%p\n", null);
	return 4;
}
