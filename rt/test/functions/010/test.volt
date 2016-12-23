//T compiles:no
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

int main()
{
	Struct s;
	ss := s(12);
	return ss.field;
}
