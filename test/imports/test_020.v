//T compiles:no
//T dependency:m1.v
//T dependency:m3.v
// More private imports, old dmd bug.

module test_020;

import m3;


int main()
{
	return m1.exportedVar;
}
