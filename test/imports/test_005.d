//T compiles:no
//T dependency:m1.d
// Constrained imports.

module test_005;

import m1 : exportedVar;


int main()
{
	return otherVar;
}
