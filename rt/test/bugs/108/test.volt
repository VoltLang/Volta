//T compiles:yes
//T retval:42
module test;


int main()
{
	bool b = true;
	uint uInt = 41;
	auto val = uInt + b;
	return cast(int)val;
}
