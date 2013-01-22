//T compiles:no
//T dependency:m1.v
//T dependency:m3.v
// Import leaks.

module test_007;

import m3 : exportedVar;


int main()
{
	return exportedVar;
}
