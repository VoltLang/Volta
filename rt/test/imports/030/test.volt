//T compiles:no
//T dependency:../deps/g.volt
//T dependency:../deps/h.volt
//T dependency:../deps/i.volt
//T error-message:13:9: error: may not bind from private import, as 'ii' does.
module test;

import g;
import h;

int main()
{
	return ii.x;
}
