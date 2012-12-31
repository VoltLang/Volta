//T compiles:yes
//T retval:42
//T dependency:m1.d
//T dependency:m6.d
//T dependency:m7.d
//T has-passed:no
// We must go deeper.

module test_024;

import m7;


int main()
{
	return m6.m1.exportedVar;
}
