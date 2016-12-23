//T compiles:yes
//T retval:42
// Test array concatenation.
module test;


int main()
{
	string s1 = "Volt";
	string s2 = " Watt";

	string sresult = s1 ~ s2;

	int[] i1 = [1, 2];
	int[] i2 = [3, 4, 5];

	int[] iresult = i1 ~ i2;

	if(sresult.length == 9 && iresult.length == 5 && iresult[3] == 4)
		return 42;
	else
		return 0;
}
