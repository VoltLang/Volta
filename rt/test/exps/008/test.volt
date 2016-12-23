//T compiles:yes
//T retval:42
// Tests no arg @property and calling into structs.
module test;


struct S
{
	int mX;

	@property void x(int _x)
	{
		mX = _x;
		return;
	}

	@property int y()
	{
		return mX;
	}
}

int main()
{
	S s;
	s.x = 42;
	return s.y;
}
