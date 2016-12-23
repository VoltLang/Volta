//T compiles:yes
//T retval:46
module test;

int doubler(int i)
{
	return i * 2;
}

int doubler(int[] ints...)
{
	int sum;
	foreach (i; ints) {
		sum += i * 2;
	}
	return sum;
}

int main()
{
	return doubler(23);
}

