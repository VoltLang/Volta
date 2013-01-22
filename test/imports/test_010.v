//T compiles:no
//T dependency:m1.v
//T dependency:m4.v
// Constrained public imports.

module test_010;

import m4 : otherVar;


int main()
{
	return exportedVar;
}
