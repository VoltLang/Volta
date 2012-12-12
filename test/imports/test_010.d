//T compiles:no
//T dependency:m1.d
//T dependency:m4.d
//T has-passed:yes
// Constrained public imports.

module test_010;

import m4 : otherVar;


int main()
{
	return exportedVar;
}
