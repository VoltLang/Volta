//T compiles:yes
//T retval:3
// Struct literals.
module test_008;

struct Point {
	short x;
	int y;
}

int getY(Point p)
{
	return p.y;
}

int main() {
	return 1 + getY({1, 2});
}
