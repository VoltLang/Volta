//T compiles:no
module test;

scope int delegate() foo() {
	int func() { return 13; }
	scope int delegate() dg = func;
	return dg;
}

int main()
{
	auto dg = foo();
	return dg();
}
