//T compiles:yes
//T retval:3
//T has-passed:no
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
