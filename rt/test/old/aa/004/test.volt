//T compiles:yes
//T retval:42
// Basic AA test, forwarding ops to value.
module test;


int main()
{
	int[string] aa;
	string key = "volt";
	aa["volt"] = 20;
	aa[key] += 1;
	aa["volt"] *= 2;
	return aa[key];
}
