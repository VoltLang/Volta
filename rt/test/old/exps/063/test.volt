//T compiles:no
module test;

struct TwoNumbers
{
	int a, b;
}

global int c = 12;
global int d = 3;

global TwoNumbers tn = {c, d};

int main()
{
	return tn.a + tn.b;
}
