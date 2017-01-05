module test;


fn main() i32
{
	b: Bar;
	// This call needs to be done.
	bar(b);
	return 0;
}

// Where this function is doesn't matter.
fn bar(Bar) {}

// This needs to be a union, and it needs to be after the call.
// But it doesn't matter if it is before the struct, as long
// as the struct is also after the function call.
union Foo
{
	gah: string;
}

// Order between this and the union doesn't matter.
// It needs to be a union or struct, class does not trigger the bug.
struct Bar
{
	foo: Foo;
}
