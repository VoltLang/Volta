//T macro:expect-failure
//T check:parsing
module test;

struct Definition(T)
{
	T x;
}

int main()
{
	return 0;
}
