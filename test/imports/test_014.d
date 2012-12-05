//T compiles:yes
//T retval:72
//T dependency:m1.d
//T dependency:m2.d
// Multiple renames.

module test_014;

import m1 : exportedVal1 = exportedVal;
import m2 : exportedVal2 = exportedVal;


int main()
{
	return exportedVal1 + exportedVal2;
}
