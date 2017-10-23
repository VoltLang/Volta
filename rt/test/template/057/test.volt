/*#D*/
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
