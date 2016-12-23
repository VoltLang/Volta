//T compiles:no
//T dependency:../deps/mod1.volt
//T dependency:../deps/mod3.volt
module test;

import mod1;
import mod3;

i32 main()
{
	return foo;
}
