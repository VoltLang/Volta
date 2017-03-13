module test;

struct ValueStruct
{
	x: i32;
}

fn main() i32
{
	aa: ValueStruct[ValueStruct];
	vs1, vs2, vs3, result: ValueStruct;
	vs1.x = 5;
	vs2.x = 5;
	result.x = 6;
	aa[vs1] = result;
	return aa.get(vs3, result).x - 6;
}
