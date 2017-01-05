module test;

import core.typeinfo : TypeInfo;


fn main() i32
{
	ti := typeid(i32);
	static is (typeof(ti) == TypeInfo);

	return 0;
}
