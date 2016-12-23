//T compiles:yes
//T retval:4
module test;


int main()
{
	string foo = "four";
	int ret;

	foreach(i, char c; foo) {
		ret = cast(int)i + 1;
	}
	return ret;
}
