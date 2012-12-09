//T compiles:yes
//T retval:42
//T dependency:m1.d
//T has-passed:no
// Renames.

module test_012;

import m1 : exportedVal1 = exportedVal;


int main()
{
	return exportedVal1;
}
