//T compiles:yes
//T retval:42
//T dependency:m1.d
//T dependency:m6.d
// Static public import in another module.

module test_023;

import m6;


int main()
{
	return m1.exportedVar;
}
