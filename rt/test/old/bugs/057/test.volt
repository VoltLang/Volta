//T compiles:yes
//T retval:7
module test;

void b(ref int val)
{
	void dgt(int param) { val = param; }
	val = 7;
}

int main()
{
	int val;
	b(ref val);
	return val;
}

