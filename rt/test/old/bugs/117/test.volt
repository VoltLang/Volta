//T compiles:no
module test;

class S
{
	int delegate(int a, int b) dg;

	int add(int a, int b)
	{
		return a + b;
	}
}

int main()
{
	auto s = new S();
	s.dg = s.add;
	return s.dg("potato", false);
}

