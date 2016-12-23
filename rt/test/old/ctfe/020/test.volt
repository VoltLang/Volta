//T compiles:yes
//T retval:6
module test;

int foo(f64 f)
{
	if (f >= 0.25) {
		return 6;
	}
	return 3;
}

int main()
{
	return #run foo(0.5);
}
