module test;


enum Enum
{
	A,
	B,
}

struct Struct
{
	global gVarStruct: i32;
}

class Class
{
	global gVarClass: i32;
}

class Deep
{
	enum Enum
	{
		C,
		D,
	}

	struct Struct
	{
		global nVarStruct: i32;
	}

	class Class
	{
		global nVarClass: i32;
	}
}

fn main() i32
{
	with (Enum) {
		var := A;
	}
	with (Struct) {
		var := gVarStruct;
	}
	with (Class) {
		var := gVarClass;
	}
	with (Deep.Enum) {
		var := C;
	}
	with (Deep.Struct) {
		var := nVarStruct;
	}
	with (Deep.Class) {
		var := nVarClass;
	}
	return 0;
}
