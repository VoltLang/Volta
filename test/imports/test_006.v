//T compiles:no
//T dependency:m1.v
//T dependency:m3.v
// Import leaks.

module test_006;

import m3;


int main()
{
	return exportedVar;
}
