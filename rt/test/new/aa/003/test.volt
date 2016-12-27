// Basic AA test.
module test;

struct Test {
	aa: i32[string];
}

int main()
{
	test: Test;
	test.aa["volt"] = 42;
	key := "volt";
	return test.aa[key] == 42 ? 0 : 1;
}
