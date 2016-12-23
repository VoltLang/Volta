//T compiles:yes
//T retval:45
module test;

int x()
{
	int j;
	foreach (i; 0 .. 10) {
		j += i;
	}
	return j;
}

int main()
{
	return #run x();
}
