module test;


enum v1 = 0xffffffff;
enum v2 = 0x1ffffffff;

fn main() i32
{
	val: i32;

	if (typeid(typeof(v1)) is typeid(u32))
		val++;
	if (typeid(typeof(v2)) is typeid(i64))
		val++;

	return val - 2;
}
