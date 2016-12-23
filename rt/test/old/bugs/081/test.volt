//T compiles:yes
//T retval:1
module test;

int getoptImpl(scope void delegate() dgt)
{
	return 1;
}

int getoptImpl(scope void delegate(string) dgt)
{
	return 2;
}

int main()
{
	void dgt() {}
	return getoptImpl(dgt);
}

