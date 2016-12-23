//T compiles:yes
//T retval:10
module test;

struct OtherStruct
{
	int x() { return 7; }
}

struct S
{
	OtherStruct os;

	@property OtherStruct someFunction()
	{
		return os;
	}

	@property int y() { return 3; }


	int proxy()
	{
		return someFunction.x() + y;
	}
}

int main()
{
	S instance;
	return instance.proxy();
}
