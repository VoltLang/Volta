//T compiles:yes
//T retval:5
module test;

int main()
{
	auto buf = new char[](1);
	buf[0] = 'a';
	auto str = new string(buf);
	buf[0] = 'b';
	return str[0] == 'a' ? 5 : 4;
}

