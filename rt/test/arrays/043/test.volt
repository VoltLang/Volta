module test;

enum VAL = 10;
enum VAL2 = 2;
alias VAI = string;

fn main() i32
{
	arr: i32[VAL + VAL2 + 1];
	aa: i32[VAI];
	aa["hi"] = 42;
	return arr.length == 13 && aa["hi"] == 42 ? 0 : 1;
}
