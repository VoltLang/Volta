//T macro:expect-failure
//T check:no valid condition
module test;

struct LinkedList!(T, val: i32)
{
	enum VAL = val;
	alias Key = static if (VAL == 0) {
		i8;
	} else if (VAL == 1) {
		i16;
	}
}

struct I8List  = mixin LinkedList!(i8, 0);
struct I16List = mixin LinkedList!(i16, 1);
struct I32List = mixin LinkedList!(i32, 2);

fn main() i32
{
	if (typeid(I8List.Key).size != 1) {
		return 1;
	}
	if (typeid(I16List.Key).size != 2) {
		return 2;
	}
	if (typeid(I32List.Key).size != 4) {
		return 3;
	}
	return 0;
}

