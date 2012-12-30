//T compiles:yes
//T retval:4
// Try to use defaultsymbols.
module test_021;

int main()
{
	size_t val = 4;

	return cast(int)val;
}
