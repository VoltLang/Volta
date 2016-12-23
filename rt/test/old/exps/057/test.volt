//T compiles:yes
//T retval:4
module test;

struct S {
	int[] x;
}

int main()
{
	S s;
	s.x = new int[](12);
	s.x[0] = 3;
	auto b = new s.x[0 .. $];
	b[0] = 1;
	return s.x[0] + b[0];
}

