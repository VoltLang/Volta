//T macro:expect-failure
//T check:expected 1 argument
module test;

struct StructDefinition!(T)
{
	T x;
}

struct Instance = mixin StructDefinition!(i32, i32);

fn main() i32
{
	Instance i;
	i.x = 2;
	return i.x - 2;
}
