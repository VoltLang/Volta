//T compiles:yes
//T retval:0
module test;

int main()
{
	wchar c = '\u1234';
	dchar c2 = '\U00012340';

	return 0;
}
