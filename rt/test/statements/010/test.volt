//T compiles:yes
//T retval:42
module test;


enum Enum
{
	A,
	B,
}

struct Struct
{
	global int gVarStruct;
}

class Class
{
	global int gVarClass;
}

class Deep
{
	enum Enum
	{
		C,
		D,
	}

	struct Struct
	{
		global int nVarStruct;
	}

	class Class
	{
		global int nVarClass;
	}
}

int main()
{
	// This leaves a IdentifierExp in the IR.
	with (Enum) {
		auto var = A;
	}
	with (Struct) {
		auto var = gVarStruct;
	}
	with (Class) {
		auto var = gVarClass;
	}
	with (Deep.Enum) {
		auto var = C;
	}
	with (Deep.Struct) {
		auto var = nVarStruct;
	}
	with (Deep.Class) {
		auto var = nVarClass;
	}
	return 42;
}
