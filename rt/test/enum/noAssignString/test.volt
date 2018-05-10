//T macro:expect-failure
//T check:no assign expression
module main;

enum StringEnum
{
	Durian = "Wolf",
	SingSing,
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