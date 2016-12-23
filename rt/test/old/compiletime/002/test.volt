//T compiles:yes
//T retval:13
module test;

int x()
{
	int a;
	version (!none) {
		a = 6;
	}
	version ((all && !none) || none) {
		a = a * 2;
	}
	version (!all) {
		a = a + 2;
	}
	version (none || all) {
		a = a + 1;
	}
	return a;
}


int main()
{
	return x();
}

