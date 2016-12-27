//T requires:exceptions
// Accessing invalid value. Exception expected.
module test;

import core.exception;

int main()
{
	aa: i32[string];
	try {
		return aa["volt"];
	} catch (Throwable) {
		return 0;
	}
}
