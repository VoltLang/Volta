//T macro:expect-failure
module main;

struct S
{
	myValue: i32;
}

struct Y
{
	myStruct: S;
}

class Z
{
	y: Y;
}

fn breakTypeSystem(ref value: const Z)
{
	value.y.myStruct.myValue = 23;
}

fn main() i32
{
	value := new Z();
	value.y.myStruct.myValue = 42;
	breakTypeSystem(ref value);
	return 0;
}
