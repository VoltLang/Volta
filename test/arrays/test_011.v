//T compiles:yes
//T retval:42
// Test string assign-concatenation.

module test_011;

int main()
{
	string result = "Volt";
	string s2 = " Watt";

	result ~= s2;

	if(result.length == 9)
		return 42;
	else
		return 0;
}
