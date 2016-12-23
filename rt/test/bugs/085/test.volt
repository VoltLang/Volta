//T compiles:yes
//T retval:0
module test;

int main()
{
	auto foo = dchar.init;
	return cast(int)foo;
}
