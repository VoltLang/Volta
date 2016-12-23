//T compiles:yes
//T retval:0
module test;

int over(int i)
{
	switch (i) {
	case 7:
	case 0: return 7;
	case 1: return 8;
	default: return 0;
	}
}

int main()
{
	return over(8000);
}