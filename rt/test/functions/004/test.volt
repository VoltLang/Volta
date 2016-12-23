//T compiles:yes
//T retval:0
module test;


void func(bool t, out int f)
{
	if (t) {
		f = 32;
	}
}

int main()
{
	int f;
	func(true, out f);
	// This second call doesn't touch f and should return set f to 0.
	func(false, out f);
	return f;
}
