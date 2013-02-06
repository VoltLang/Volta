//T compiles:yes
//T retval:6
//T has-passed:no
// is test
module test_014;

int main()
{
	// Emtpy list
	string arr;
	int ret;

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
