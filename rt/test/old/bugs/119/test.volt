//T compiles:yes
//T retval:4
module test;

int main()
{
	int[int] aa;
	aa[1] = 54;
	aa[2] = 75;
	return cast(int)(aa.values.length + aa.keys.length);
}
