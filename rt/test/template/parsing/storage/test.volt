module main;

struct Data!(T)
{
}

struct IntegerData = mixin Data!(const(i32));

fn main() i32
{
	return 0;
}
