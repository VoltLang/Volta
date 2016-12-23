//T compiles:yes
//T retval:7
module test;

int main()
{
	if (true) {
		return 7;
	}
	// Never reached.
}

