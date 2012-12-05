//T compiles:no
//T dependency:m1.d
//T dependency:m3.d
// More private imports, old dmd bug.

module test_020;

import m3;


int main()
{
	return m1.exportedVal;
}
