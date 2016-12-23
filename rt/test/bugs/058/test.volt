//T compiles:yes
//T retval:13
module test;

void a()
{
	void func() {}
}

void a(int x)
{
	void func2() {}
}

int main()
{
	return 13;
}

