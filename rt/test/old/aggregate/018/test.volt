//T compiles:yes
//T retval:42
module test;


class A
{
	int mX;

	this(int x)
	{
		mX = x;
		return;
	}

	int getX()
	{
		return mX;
	}
}

class B : A
{
	this(int x)
	{
		super(x + 1);
		return;
	}
}

int main()
{
	auto b = new B(41);
	return b.getX();
}
