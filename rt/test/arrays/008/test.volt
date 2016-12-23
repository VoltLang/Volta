//T compiles:yes
//T retval:3
// test zero length string literal
module test;


int main()
{
	int ret;

	// Yes this is a length zero array with a valid pointer.
	// This is needed for C integration.
	auto weird = "";

	if (weird !is null)
		ret += 1;
	if (weird.ptr !is null)
		ret += 1;
	if (weird.length is 0)
		ret += 1;

	return ret;
}
