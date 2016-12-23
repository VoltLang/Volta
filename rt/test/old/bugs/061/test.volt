//T compiles:yes
//T retval:32
module test;

int main()
{
	int[string] aa;
	aa["foo"] = 32;
	if (auto p = "foo" in aa) {
		return *p;
	} else {
		return 0;
	}
}

