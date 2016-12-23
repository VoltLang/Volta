//T compiles:yes
//T retval:13
module test;

import core.object : Object;

int main()
{
	auto obj = Object.init;
	return obj is null ? 13 : 27;
}
