//T compiles:yes
//T retval:42
//T dependency:m1.d
//T has-passed:yes
// Renames.

module test_012;

import m1 : exportedVar1 = exportedVar;


int main()
{
	return exportedVar1;
}
