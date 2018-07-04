//T macro:import
module main;


union UnionTemplate!(T, Y, U)
{
	a: T;
	b: Y;
	c: U;
}

union Edutainment = UnionTemplate!(i32, i64, i8);

fn main() i32
{
	e: Edutainment;
	e.b = 12;
	if (e.a != 12 || e.b != 12 || e.c != 12 || typeid(Edutainment).size != typeid(i64).size) {
		return 1;
	}
	e.c = 0;
	return e.a;
}
