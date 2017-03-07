//T default:no
//T macro:expect-failure
//T check:parsing
module test;

struct Definition(T)
{
	T x;
}

alias Instance = Definition!i32;

int main()
{
	Instance i;
	return i.x;
}
