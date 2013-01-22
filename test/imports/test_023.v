//T compiles:yes
//T retval:42
//T dependency:m1.v
//T dependency:m6.v
// Static public import in another module.

module test_023;

import m6;


int main()
{
	return m1.exportedVar;
}
