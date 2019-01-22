//T macro:expect-failure
module main;

struct S
{
	myValue: i32;
}

fn breakTypeSystem(ref in value: S)
{
	value.myValue += 32;
}

fn main() i32
{
	value: S;
	value.myValue = 42;
	breakTypeSystem(ref value);
	return 0;
}
