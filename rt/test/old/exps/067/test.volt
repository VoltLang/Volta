//T compiles:yes
//T retval:2
// Reordering arguments with labels.
module test;

@label int sub(int a, int b) {
	return a - b;
}

int main()
{
	return sub(b:1, a:3);
}
