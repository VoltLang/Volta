//T compiles:yes
//T retval:8
module test;

int main() {
	int x;
	x = 2;
	int func()
	{
		int y;
		if (x == 2) {
			y = 4;
		}
		return x * y;
	}
	return func();
}
