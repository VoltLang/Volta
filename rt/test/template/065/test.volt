//T default:no
//T macro:expect-failure
//T check:unidentified identifier
module test;


struct Instance = mixin StructDefinition!(i32);

fn main() i32
{
	return 0;
}
