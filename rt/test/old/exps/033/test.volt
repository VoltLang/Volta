//T compiles:yes
//T retval:4
module test;

int main()
{
	ubyte uB = 0xff;
	byte  sB = cast(byte)-1;

	return
		(cast(int)uB == 0xff) +
		(cast(uint)uB == cast(uint)0xff) +
		(cast(int)sB == 0xffff_ffff) +
		(cast(uint)sB == cast(uint)0xffff_ffff);
}
