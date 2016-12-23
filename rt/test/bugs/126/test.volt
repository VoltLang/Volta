//T compiles:yes
//T retval:6
//T dependency:../deps/c.volt
//T dependency:../deps/d.volt
module test;

import c;
import d;

int main()
{
	return foo(3);
}
