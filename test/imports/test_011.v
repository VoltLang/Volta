//T compiles:no
//T dependency:m1.v
//T dependency:m2.v
// Multiple imports per import deprecated.

module test_011;

import m1, m2;


int main()
{
	return exportedVar;
}
