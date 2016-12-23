//T compiles:yes
//T retval:42
module test;


int main()
{
	Bar b;
	// This call needs to be done.
	bar(b);
	return 42;
}

// Where this function is doesn't matter.
void bar(Bar) {}

// This needs to be a union, and it needs to be after the call.
// But it doesn't matter if it is before the struct, as long
// as the struct is also after the function call.
union Foo
{
	string gah;
}

// Order between this and the union doesn't matter.
// It needs to be a union or struct, class does not trigger the bug.
struct Bar
{
	Foo foo;
}
