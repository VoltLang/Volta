//T compiles:no
// Test accessing static functions through instance members.
module test;

struct Maths
{
	global int Shoble(int a)
	{
		return a;
	}
}

int main()
{
	Maths maths;
	return maths.Shoble(23);
}
