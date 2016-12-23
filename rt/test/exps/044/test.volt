//T compiles:yes
//T retval:28
module test;

struct S
{
	int field;

	int opIndex(int x)
	{
		return x + field;
	}

	S opAdd(S right)
	{
		S _out;
		_out.field = field + right.field;
		return _out;
	}
}

int main()
{
	S a, b;
	a.field = 10;
	b.field = a[8];
	auto c = a + b;
	return c.field;
}

