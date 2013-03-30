//T compiles:yes
//T retval:42
// Passing pointer TypeReferences.
module test_020;


struct Struct
{
	int t;
}

union Union
{
	int t;
}

void func(Struct*, Union*)
{
	return;
}

int main()
{
	Struct s;
	Union* u;
	func(&s, u);

	return 42;
}
