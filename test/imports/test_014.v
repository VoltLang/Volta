//T compiles:yes
//T retval:74
//T dependency:m1.v
//T dependency:m2.v
// Multiple renames.

module test_014;

import m1 : exportedVar1 = exportedVar;
import m2 : exportedVar2 = exportedVar;


int main()
{
	return exportedVar1 + exportedVar2;
}
