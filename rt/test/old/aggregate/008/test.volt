//T compiles:no
// Struct literals.
module test;


struct Point
{
	short x;
	int y;
}

int getY(Point p)
{
	return p.y;
}

int main()
{
	// Struct literals in function calls not supported.
	return 1 + getY({1, 2});
}
