//T compiles:yes
//T retval:4
// Try to use defaultsymbols.
module test;


int main()
{
	size_t val = 4;

	return cast(int)val;
}
