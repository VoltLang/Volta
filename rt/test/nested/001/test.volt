//T compiles:yes
//T retval:6
module test;

int main() {
	int x;
	x = 2;
	int func(int y)
	{ 
		return y * x;
	}
	return func(3);
}
