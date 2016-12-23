//T compiles:yes
//T retval:15
module test;

class Foo {}

void bar(out Foo[] var)
{
	Foo f;
	var ~= f;
}

int main()
{
	return 15;
}
