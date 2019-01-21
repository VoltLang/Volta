//T macro:expect-failure
//T has-passed:no
module main;

struct S
{
	myValue: i32;
}

struct Y
{
	myStruct: S;
}

fn breakTypeSystem(ref value: const Y)
{
	value.myStruct.myValue = 23;
}

fn main() i32
{
	value: Y;
	value.myStruct.myValue = 42;
	breakTypeSystem(ref value);
	return 0;
}
