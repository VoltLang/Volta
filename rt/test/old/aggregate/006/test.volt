//T compiles:yes
//T retval:42
// Making sure that local/global variables don't change struct layout.
module test;


struct Source
{
	int pad;
	local int localVal;
	int val;
}

struct Dest
{
	int pad;
	int val;
}

int main()
{
	Source src;
	Dest dst;

	src.val = 42;
	dst = *cast(Dest*)&src;

	return dst.val;
}
