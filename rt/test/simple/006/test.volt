// Tests TypeInfo lowering.
module test;

import core.typeinfo : TypeInfo;


fn main() i32
{
	tinfo: TypeInfo = typeid(i32);
	return (cast(i32)tinfo.size == 4) ? 0 : 1;
}

