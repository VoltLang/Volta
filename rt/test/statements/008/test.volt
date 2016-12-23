//T compiles:yes
//T retval:1
module test;

import core.exception;


int main()
{
	try {
		throw new Exception("hello");
	} catch (Exception e) {
		return 1;
	}
	return 0;
}
