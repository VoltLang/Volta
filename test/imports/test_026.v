//T compiles:yes
//T retval:42
//T dependency:m1.v
//T dependency:m9.v
// Non-public import rebind.

module test_025;

import m9;


int main()
{
	return exportedVar1;
}
