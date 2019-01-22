//T macro:expect-failure
module main;

struct S
{
	myValue: i32;
}

fn breakTypeSystem(ref value: const S)
{
	*(&value.myValue) = 12;
}

fn main() i32
{
	value: S;
	value.myValue = 42;
	breakTypeSystem(ref value);
	return 0;
}
