//T compiles:yes
//T retval:42
module test;


int main()
{
	int ret = 4;

	switch (3) {
	case 2:
		return 2;
	case 3: // This doesn't fall through as expected.
	default:
		ret = 42;
	}
	return ret;
}
