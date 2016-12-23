//T compiles:yes
//T retval:42
module test;

int main()
{
	aa : ulong[ulong];
	aa[ulong.max] = ulong.max;
	aa = new aa[..];
	return aa[ulong.max] > uint.max ? 42 : 0;
}
