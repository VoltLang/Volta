//T compiles:yes
//T retval:0
module test;

import core.object : Object;

enum SomeEnum { A, B, C}

void foo(SomeEnum se)
{
	return;
}

void foo(Object obj)
{
	return;
}

int main()
{
	foo(SomeEnum.A);
	return 0;
}

