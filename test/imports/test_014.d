//T compiles:yes
//T retval:74
//T dependency:m1.d
//T dependency:m2.d
//T has-passed:yes
// Multiple renames.

module test_014;

import m1 : exportedVar1 = exportedVar;
import m2 : exportedVar2 = exportedVar;


int main()
{
	return exportedVar1 + exportedVar2;
}
