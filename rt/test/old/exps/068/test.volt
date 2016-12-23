//T compiles:no
module test;

@label int sub(int a, int b) {
	return a - b;
}

int main()
{
	return sub(1, a:3);
}
