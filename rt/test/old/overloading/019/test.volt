//T compiles:yes
//T retval:14
module test;

int sproznak(int x)
{
	return x;
}

@property double PI()
{
	return 3.1415926538;
}

@property void IGNORE(string s)
{
}

struct AnotherStruct
{
	@property int overloadedProp()
	{
		return 7;
	}

	@property void overloadedProp(int x)
	{
	}
}

struct Struct
{
	int x;
	AnotherStruct as;

	@property int block(int b)
	{
		return x = b;
	}

	@property int block()
	{
		return x;
	}

	int foo()
	{
		block = 7;
		auto b = block;
		auto c = as.overloadedProp;
		as.overloadedProp = 54;
		return sproznak(block) + c;
	}
}

int main()
{
	double d = PI;
	IGNORE = "foo";
	Struct s;
	return s.foo();
}

