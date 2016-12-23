//T compiles:no
module test;

struct S {
	Y y;
	int b;
}

struct Y {
	int x;
}

int main()
{
	S s;
	s.b = 7;
	s.y.x = 3;
	int x;
	with (s.y) with (s) {
		return b + x;
	}
}

