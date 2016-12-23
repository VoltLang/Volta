//T compiles:yes
//T retval:42
module test;


void func()
{
	int val = 4;
	switch (val) {
	case 3: return other();
	case 5: return other();
	default:
	}
	// Bug, where empty default would cause a unreachable error.
}

void other() {}

int main()
{
	func();
	return 42;
}
