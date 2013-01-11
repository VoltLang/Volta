//T compiles:no
//T dependency:m1.d
//T dependency:m2.d
// Multiple imports per import deprecated.

module test_011;

import m1, m2;


int main()
{
	return exportedVar;
}
