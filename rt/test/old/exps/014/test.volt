//T compiles:yes
//T retval:6
// is test
module test;


int main()
{
	int ret;

	// Emtpy list
	string arr;

	if (arr is null)
		ret += 1;
	if (arr.ptr is null)
		ret += 1;
	if (arr.length is 0)
		ret += 1;

	// Populated list.
	arr = "four";

	if (arr !is null)
		ret += 1;
	if (arr.ptr !is null)
		ret += 1;
	if (arr.length is 4)
		ret += 1;

	return ret;
}
