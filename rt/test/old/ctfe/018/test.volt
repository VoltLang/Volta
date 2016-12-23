//T compiles:yes
//T retval:6
module test;

f64 foo()
{
	return 0.0 + 0.5;
}

int main()
{
	return (#run foo()) >= 0.25 ? 6 : 3;
}
