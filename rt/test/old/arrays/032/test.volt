//T compiles:yes
//T retval:0
module test;

int main()
{
	auto aa = new char[](1);
	aa[0] = 'a';
	auto bb = new char[](1);
	bb[0] = 'a';
	auto a = [aa];
	auto b = [bb];
	if (a != b) {
		return 1;
	}
	return 0;
}

