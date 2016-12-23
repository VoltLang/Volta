//T compiles:no
// Assign null to AA.
module test;


int main()
{
	int result = 42;
	auto aa = [3:result];
	aa = null;
	return aa[3];
}
