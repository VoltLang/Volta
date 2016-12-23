//T compiles:yes
//T retval:exception
// Reset AA.
module test;


int main()
{
	auto aa = [3:42];
	aa = [];
	return aa[3];
}
