// Implicit conversion of string literals.
module test;

extern(C) fn strlen(str: const(char)*) size_t;

fn foo(str: const(char)*) size_t
{
	return strlen(str);
}

fn main() i32
{
	len: size_t = foo("Volt is Awesome");
	if (len == strlen("Volt is Awesome") && len == 15) {
		return 0;
	}
	return 42;
}
