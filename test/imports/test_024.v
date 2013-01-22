//T compiles:yes
//T retval:42
//T dependency:m1.v
//T dependency:m6.v
//T dependency:m7.v
// We must go deeper.

module test_024;

import m7;


int main()
{
	return m6.m1.exportedVar;
}
