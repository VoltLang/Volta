//T compiles:yes
//T retval:15
module test;

struct TwoNumbers
{
	int a, b;
}

int main()
{
	int c = 12;
	int d = 3;
	TwoNumbers tn = {c, d};
	return tn.a + tn.b;
}
