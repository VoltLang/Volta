//T compiles:yes
//T retval:42
// Anon base typed enum.
module test_027;

enum : uint
{
	FOO = 5,
}

int main()
{
	if (typeid(typeof(FOO)) is typeid(uint))
		return 42;
	return 0;
}
