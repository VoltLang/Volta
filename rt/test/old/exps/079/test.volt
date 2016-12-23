//T compiles:yes
//T retval:12
module test;

int main(string[] args)
{
	return __LOCATION__[$-11 .. $] == "test.volt:7" ? 12 : 15;
}
