//T compiles:yes
//T dependency:../deps/mod1.volt
//T dependency:../deps/mod2.volt
//T retval:42
module test;

import mod1;
import mod2;

i32 main()
{
	return foo;
}
