module test;

struct S!(T, val: T)
{
	enum E = val / 2;
}

struct SS = mixin S!(i32, 32);
struct SSS = mixin S!(u32, 34u);

fn main() i32
{
	return cast(i32)SSS.E - 17;
}
