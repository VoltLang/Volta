//T compiles:yes
//T retval:12
//T dependency:../deps/m10.volt
//T dependency:../deps/m11.volt
module test;

static import test2;
static import foo.bar.baz;

int main()
{
	test2.setX();
	return foo.bar.baz.x;
}

