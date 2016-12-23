//T compiles:yes
//T retval:1
module test;


int main()
{
	if (is(const(int) == const(int))) {
		return 1;
	} else {
		return 2;
	}
}
