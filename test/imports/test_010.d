//T compiles:no
//T dependency:m1.d
//T dependency:m4.d
// Constrained public imports.

module test_010;

import m4 : otherVar;


int main()
{
	return exportedVar;
}
