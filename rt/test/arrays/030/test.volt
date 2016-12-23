//T compiles:yes
//T retval:17
module test;

int main()
{
	auto s = ["hello", null];
	string[2] ss = ["world", null];
	auto sss = [["what", null]];
	return 17;
}
