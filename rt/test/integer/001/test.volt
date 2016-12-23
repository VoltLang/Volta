//T compiles:yes
//T retval:0
module test;


int main()
{
	char charVar;

	static is (typeof(charVar + charVar) == int);

	return 0;
}
