//T compiles:yes
//T retval:42
//T dependency:m1.v
//T dependency:m4.v
// Constrained public imports.

module test_009;

import m4 : exportedVar;


int main()
{
	return exportedVar;
}
