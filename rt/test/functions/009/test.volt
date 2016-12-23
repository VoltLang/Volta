//T compiles:yes
//T retval:19
module test;

struct Struct
{
	int field;

	this(int x)
	{
		field = x;
	}

	this(int x, int y)
	{
		field = x + y;
	}
}

union Union
{
	int field;
	int fald;

	this(int x)
	{
		fald = x;
	}
}

int main()
{
	s := Struct(12);
	y := Struct(2, 3);
	u := Union(2);
	return s.field + y.field + u.field;
}
