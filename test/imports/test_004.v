//T compiles:yes
//T retval:42
//T dependency:m1.v
// Constrained imports.

module test_004;

import m1 : exportedVar;


int main()
{
	return exportedVar;
}
