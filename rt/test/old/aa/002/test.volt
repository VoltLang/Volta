//T compiles:yes
//T retval:42
// Basic AA test.
module test;


int main()
{
	int[string] aa;
	string key = "volt";
	aa[key] = 42;
	return aa["volt"];
}
