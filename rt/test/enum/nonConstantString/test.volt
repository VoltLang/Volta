//T macro:expect-failure
//T check:unevaluatable at compile time
module main;

global s: string;

enum StringEnum
{
	Durian = "Wolf",
	SingSing = s,
}

enum AnotherString : string
{
	Flabbol = "Wolf",
}

fn main() i32
{
	if (StringEnum.Durian != "Wolf" || StringEnum.Durian.ptr is null) {
		return 1;
	}
	if (StringEnum.Durian != AnotherString.Flabbol) {
		return 2;
	}
	return 0;
}