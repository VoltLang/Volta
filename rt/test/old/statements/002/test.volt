//T compiles:yes
//T retval:7
module test;

struct S {
	Y y;
}

struct Y {
	int x;
}

int main()
{
	S s;
	s.y.x = 7;
	with (s.y) {
		return x;
	}
}

