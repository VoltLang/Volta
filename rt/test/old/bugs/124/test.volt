//T compiles:yes
//T retval:42
module test;

import core.typeinfo : TypeInfo;


int main()
{
	auto ti = typeid(int);
	static is (typeof(ti) == TypeInfo);

	return 42;
}
