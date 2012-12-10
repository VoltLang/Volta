//T compiles:yes
//T retval:74
//T dependency:m1.d
//T dependency:m2.d
//T has-passed:no
// Multiple renames.

module test_014;

import m1 : exportedVal1 = exportedVar;
import m2 : exportedVal2 = exportedVar;


int main()
{
	return exportedVal1 + exportedVal2;
}
