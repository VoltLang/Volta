//T compiles:yes
//T retval:42
// Test array assign-concatenation.
module test;


int main()
{
	string sresult = "Volt";
	string s2 = " Watt";

	sresult ~= s2;

	int[] iresult = [1, 2];
	int[] i2 = [3, 4, 5];

	iresult ~= i2;

	if(sresult.length == 9 && iresult.length == 5 && iresult[3] == 4)
		return 42;
	else
		return 0;
}
