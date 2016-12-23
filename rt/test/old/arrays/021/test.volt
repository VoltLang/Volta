//T compiles:yes
//T retval:42
// Implicit conversion of string literals.
module test;

extern(C) size_t strlen(const(char)* str);

size_t foo(const(char)* str) {
	return strlen(str);
}

int main()
{
	size_t len = foo("Volt is Awesome");
	if (len == strlen("Volt is Awesome") && len == 15) {
		return 42;
	}
	return 0;
}
