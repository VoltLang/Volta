//T compiles:yes
//T retval:42
module test;

int main()
{
	int[string] aa;
	return aa["volt"] = 42;
}

