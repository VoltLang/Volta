//T compiles:yes
//T retval:42
// Test appending to an array.

module test_013;

int main()
{
	int[] i = [0, 1];
	i = i ~ 2;

	double[] d = [0.0, 1.0];
	d = d ~ 2;

	string[] s = ["Volt", "is", "truly"];
	s = s ~ "amazing";

	if(i[0] == 0 && i[1] == 1 && i[2] == 2 && i.length == 3 &&
	   d[0] == 0 && d[1] == 1 && d[2] == 2 && d.length == 3 &&
	   s[3] == "amazing" && s.length == 4)
		return 42;
	else
		return 0;
}
