//T compiles:yes
//T retval:42
// Union test.
module test;


union Test
{
	int i;
	uint u;
	long l;
}

int main()
{
	auto tid = typeid(Test);

	Test t;
	t.i = -1;
	if (tid.size == 8 && t.u == cast(uint)-1)
		return 42;
	return 0;
}
