// Multiple Variable declarations in one.
module test;


alias Sint32 = i32;

fn main() i32
{
	x, y: i32;
	z, w: Sint32;
	strArr1, strArr2: string[];

	x = 2; y = 3;
	z = 2; w = 6;
	return x + z - 4;
}
