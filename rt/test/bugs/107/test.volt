//T compiles:yes
//T retval:1
//T dependency:../deps/a.volt
module b;

static import a;

int main()
{
	return a.bork(1);
}
