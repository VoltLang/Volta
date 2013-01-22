//T compiles:yes
//T retval:42
//T dependency:m1.v
//T dependency:m4.v
// Public imports.

module test_008;

import m4;


int main()
{
	return exportedVar;
}
