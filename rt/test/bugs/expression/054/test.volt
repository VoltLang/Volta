//T macro:expect-failure
//T check:'field' is neither field
//T has-passed:no
module test;

struct Struct
{
	field: i32;
}

fn main() i32
{
	arrayOfStruct: Struct[] = new Struct[](1);

	// Should not be able to access field here.
	return arrayOfStruct.field;
}
