//T compiles:yes
//T retval:3
module test;

int main()
{
	size_t x = true ? 3 : 4;
	return cast(int) x;
}
