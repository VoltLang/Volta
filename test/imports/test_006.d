//T compiles:no
//T dependency:m1.d
//T dependency:m3.d
//T has-passed:no
// Import leaks.

module test_006;

import m3;


int main()
{
	return exportedVar;
}
