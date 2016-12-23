//T compiles:yes
//T retval:12
module test;

int x(int j)
{
	int val = 3;
	switch (j) {
	default:
		val *= 2;
		break;
	case 7:
		val = 12;
		break;
	}
	return val;
}

int main()
{
	return #run x(7);
}
