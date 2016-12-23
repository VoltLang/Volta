//T compiles:yes
//T retval:7
module test;

int a(int x)
{
	return x;
}

int a()
{
	return 7;
}

class SomeParent
{
	int mX;

	this(int x)
	{
		mX = x;
		return;
	}
}

class SomeChild : SomeParent
{
	this()
	{
		super(a());
		return;
	}
}

int main()
{
	auto sc = new SomeChild();
	return sc.mX;
}

