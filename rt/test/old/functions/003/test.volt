//T compiles:yes
//T retval:0
module test;

void func(int i, int x)
{
	void nest() {
	}
	nest();
}

void func()
{
	void nest() {
	}
	nest();
}

int main()
{
	func();
	func(1, 2);
	return 0;
}

