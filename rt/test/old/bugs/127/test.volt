//T compiles:yes
//T retval:5
module test;

enum Foo : uint { one = 1, two, three }

int main()
{
	uint foo = Foo.three;
	return cast(int) (Foo.two + foo);
}
