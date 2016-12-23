//T compiles:yes
//T retval:23
module test;

int main()
{
	bool a = 1.2 || 3.4;
	return a ? 23 : 15;
}
