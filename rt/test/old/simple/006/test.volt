//T compiles:yes
//T retval:4
// Tests TypeInfo lowering.
module test;

import core.typeinfo : TypeInfo;


int main()
{
	TypeInfo tinfo = typeid(int);
	return cast(int) tinfo.size;
}
