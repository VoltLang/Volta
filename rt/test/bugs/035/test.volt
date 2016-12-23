//T compiles:no
//T retval:2
module test;

void foo(const(int*))
{
	return;
}

int main()
{
	foo([1,2,3]);
	return 2;
}

