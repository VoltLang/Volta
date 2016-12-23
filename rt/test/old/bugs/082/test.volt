//T compiles:yes
//T retval:5
module test;

int main()
{
	void dgt() {}
	int x = 5;
	getoptImpl(ref x, dgt);
	return x;
}

void getoptImpl(ref int args, scope void delegate() dgt)
{
}

void getoptImpl(ref int args, scope void delegate(string) dgt)
{
	args = 34;
}

