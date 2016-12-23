//T compiles:yes
//T retval:9
module test;

import core.varargs;

int foo(int x = 2, ...)
{
	int sum = x;
	va_list vl;
	va_start(vl);
	foreach (tid; _typeids) {
		sum += va_arg!i32(vl);
	}
	return sum;
}

int main()
{
	return foo(2, 3, 4);
}
