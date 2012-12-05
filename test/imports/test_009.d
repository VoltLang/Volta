//T compiles:yes
//T retval:42
//T dependency:m1.d
//T dependency:m4.d
// Constrained public imports.

module test_009;

import m4 : exportedVal;


int main()
{
	return exportedVal;
}
