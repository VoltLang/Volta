//T compiles:yes
//T retval:exception
// Accessing invalid value. Exception expected.
module test;


int main()
{
	int[string] aa;
	return aa["volt"];
}
