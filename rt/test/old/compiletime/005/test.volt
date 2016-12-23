//T compiles:yes
//T feature:nodebug
//T retval:0
module test;

int main()
{
	int x;
	debug x = 32;
	return x;
}
