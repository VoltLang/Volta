module test;


fn main() i32
{
	foo: i32[4];
	f := cast(void[])foo;
	return (cast(i32) f.length == 16) ? 0 : 1; // 4 * 4 = 16
}
