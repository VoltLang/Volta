//T compiles:yes
//T retval:4
module test;


int main()
{
	const(char)[][1] foo;
	foo[0] = "four";
	return cast(int)foo[0].length;
}
