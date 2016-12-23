//T compiles:yes
//T retval:43
// Simple static functions.
module test;

struct Maths
{
	local int Glozum(int a)
	{
		return a * 2;
	}

	global int Shoble(int a)
	{
		return a;
	}
}

int main()
{
	return Maths.Glozum(10) + Maths.Shoble(23);
}
