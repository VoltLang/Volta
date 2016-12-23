//T compiles:yes
//T retval:17
module test;

int main()
{
	auto dg1 = cast(void delegate()) null;
	void delegate() dg2;
	if (dg1 is null && dg2 is null) {
		return 17;
	}
	return 12;
}

