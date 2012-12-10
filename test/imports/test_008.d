//T compiles:yes
//T retval:42
//T dependency:m1.d
//T dependency:m4.d
//T has-passed:yes
// Public imports.

module test_008;

import m4;


int main()
{
	return exportedVar;
}
