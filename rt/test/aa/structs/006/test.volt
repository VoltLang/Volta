module test;

struct ValueStruct
{
	x: i32;
}

fn main() i32
{
	vs1, vs2, vs3: ValueStruct;
	vs1.x = 1;
	vs2.x = 6;
	aa1: ValueStruct[ValueStruct];
	aa2: i32[ValueStruct];
	aa3: i32[][ValueStruct];
	aa3[vs3] = [4];
	aa4: ValueStruct[i32];
	assert(aa1.get(vs1, vs2).x == 6);
	assert(aa2.get(vs1, 6) == 6);
	assert(aa3.get(vs1, [6])[0] == 6);
	assert(aa3.get(vs3, [6])[0] == 4);
	assert(aa4.get(6, vs2).x == 6);
	return 0; 
}
