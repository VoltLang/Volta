//T compiles:yes
//T retval:42
// Basic AA test.
module test;


struct Test {
	int[string] aa;
}

int main()
{
	Test test;
	test.aa["volt"] = 42;
	string key = "volt";
	return test.aa[key];
}
