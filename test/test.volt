//T compiles:yes
//T retval:42
//T has-passed:no
module test;


mixin Foo = `
struct {
	i32 x, y, z;
}
`;

int main()
{
	Foo foo;
	foo.x = 42;
	return foo.x;
}
