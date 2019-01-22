//T macro:expect-failure
//T has-passed:no
module main;

struct S
{
	myValue: i32;

	fn setMyValue(value: i32)
	{
		myValue = value;
	}
}

fn breakTypeSystem(ref value: const S)
{
	value.setMyValue(17);
}

fn main() i32
{
	value: S;
	value.myValue = 42;
	breakTypeSystem(ref value);
	return 0;
}
