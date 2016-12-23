//T compiles:yes
//T retval:7
// Struct literals and the same hiding in arrays.
module test;

struct A { int x; }

int main()
{
	A a = {1};
	A[] b = [{2}];
	A[][] c = [[{3}, {4}]];
	return a.x + b[0].x + c[0][1].x;
}

