//T compiles:no
//T dependency:m1.v
// Constrained imports.

module test_005;

import m1 : exportedVar;


int main()
{
	return otherVar;
}
