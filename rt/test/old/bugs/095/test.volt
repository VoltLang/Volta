//T compiles:yes
//T retval:15
module test;

int main()
{
	size_t n = 10;
	foreach (i; 0 .. n) {
	}
	return 15;
}

