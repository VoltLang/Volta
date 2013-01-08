//T compiles:yes
//T retval:42
//T dependency:m1.d
//T dependency:m9.d
// Non-public import rebind.

module test_025;

import m9;


int main()
{
	return exportedVar1;
}
