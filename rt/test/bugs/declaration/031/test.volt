module test;

fn main() i32
{
	aa: i32[i32];
	aa[1] = 54;
	aa[2] = 75;
	return cast(i32)(aa.values.length + aa.keys.length) - 4;
}
