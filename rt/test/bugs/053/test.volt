//T compiles:yes
//T retval:24
module test;

int main()
{
	int sum;
	foreach (a; [1, 2, 3]) {
		foreach (b; [1, 1, 2]) {
			sum += b * a;
		}
	}
	return sum;
}

