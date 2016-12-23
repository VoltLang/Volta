//T compiles:yes
//T retval:42
module test;

import core.object : Object;


void func(scope Object obj)
{
	static is (typeof(obj) == scope Object);

	typeof(obj) var;

	static is (typeof(var) == scope Object);
}

int main()
{
	return 42;
}
