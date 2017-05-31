module main;

// This tests two bugs.
// 1, We could not lookup values via T.Val because volta
//    for some reason tought that T was a value.
// 2, Argument was resolved in Def.myScope scope and not
//    in the scope Def.myScope.parent which is the scope
//    that contains the "struct Def = ..." definition.
struct Bug!(T)
{
	// This is here to make sure the T argument
	// is resolved in the right scope.
	struct HasEnumValue
	{
		enum u32 Val = 5;
	}

	// Pick up the Val enum value from the T argument.
	enum u32 E = T.Val;
}

// We get the value from this struct.
struct HasEnumValue
{
	enum u32 Val = 4;
}

// This should make E be 4, as it uses the outer struct.
struct Def = mixin Bug!(HasEnumValue);

fn main() i32
{
	return Def.E == 4 ? 0 : 1;
}
