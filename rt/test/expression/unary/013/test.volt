module test;

enum AnEnum
{
	Value = 320
}

fn main() i32
{
	a := new i32[](AnEnum.Value);
	a[160] = 32;
	return a[160] - (a[243] + 32);
}
