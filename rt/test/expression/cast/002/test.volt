module test;


fn main() i32
{
	True: bool = true;
	False: bool = false;
	val: i32;

	val += cast(i32)(true);
	val += cast(i32)(!false);
	val += cast(i32)(True);
	val += cast(i32)(!False);
	val += cast(i32)(True == !False);
	return val - 5;
}
