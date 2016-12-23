//T compiles:yes
//T retval:1
module test;

int main()
{
	int[string] aa;
	int[string] bb;
	aa["hello"] = 42;
	return cast(int)(aa.length + bb.length);
}
