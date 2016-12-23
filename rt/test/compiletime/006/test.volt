//T compiles:yes
//T feature:debug
//T retval:32
module test;

int main()
{
	int x;
	debug x = 32;
	return x;
}
