//T compiles:yes
//T retval:0
module test;

struct S {
	int x;
}

int main()
{
	S s;
	s.x = 32;
	s = S.init;
	return s.x;
}
