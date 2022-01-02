//T macro:expect-failure
//T check:already defined in this scope
module test;

struct StructDefinition!(T: i32)
{
	T b;
}

struct Instance = mixin StructDefinition!(i32);
struct Instance = mixin StructDefinition!(i32);

fn main() i32
{
	return 0;
}
