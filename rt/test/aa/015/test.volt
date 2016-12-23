//T compiles:yes
//T retval:31
module test;

int main()
{
	int[string] aa;
	aa["hello"] = 35;
	aa.remove("hello");
	return aa.get("hello", 31);
}

