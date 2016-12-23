//T compiles:yes
//T retval:2
module test;


enum v1 = 0xffffffff;
enum v2 = 0x1ffffffff;

int main()
{
	int val;

	if (typeid(typeof(v1)) is typeid(int))
		val++;
	if (typeid(typeof(v2)) is typeid(long))
		val++;

	return val;
}
