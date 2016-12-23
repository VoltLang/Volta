//T compiles:yes
//T retval:17
module test;

void foo(ref string s)
{
	s = "hi";
}

void foo(ref int i)
{
	i = 17;
}

int main()
{
	int x;
	foo(ref x);
	return x;
}

