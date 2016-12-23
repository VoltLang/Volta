//T compiles:yes
//T retval:8
module test;

int main()
{
	int i;
	foreach (0 .. 8) {
		i++;
	}
	return i;
}
