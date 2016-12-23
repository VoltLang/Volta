//T compiles:yes
//T retval:2
module test;


int main()
{
	auto str = "foo".ptr;
	return str[0] == 'f' ? 2 : 1;
}
