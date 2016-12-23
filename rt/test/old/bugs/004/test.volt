//T compiles:yes
//T retval:42
// Postfixes on things don't work.
module test;


int main()
{
	auto id = typeid(int);
	auto str1 = id.mangledName; // Works

	auto str2 = typeid(int).mangledName; // Doesn't
	return 42;
}
