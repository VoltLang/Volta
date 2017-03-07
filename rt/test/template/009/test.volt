module test;

struct Math!(T)
{
	global fn add(a: T, b: T) T
	{
		return a + b;
	}
}

struct IntegerMath = mixin Math!i32;
struct FloatMath = mixin Math!f32;

fn main() i32
{
	return IntegerMath.add(5, 2) - cast(i32)FloatMath.add(6.0f, 1.3f);
}
