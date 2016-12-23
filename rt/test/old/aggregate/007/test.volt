//T compiles:yes
//T retval:3
// Struct literals.
module test;


struct Point
{
	short x;
	int y;
}

int main()
{
	Point p = {1, 2};
	return p.x + p.y;
}
