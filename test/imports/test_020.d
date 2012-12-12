//T compiles:no
//T dependency:m1.d
//T dependency:m3.d
//T has-passed:yes
// More private imports, old dmd bug.

module test_020;

import m3;


int main()
{
	return m1.exportedVar;
}
