module test;

struct Foo!(K, V)
{
	enum A
	{
		AA,
		BB,
	}

	enum C = 2;
}

struct Instance = mixin Foo!(i32, i16);
struct Instance2 = mixin Foo!(f32, f32);

fn main() i32
{
	return Instance.A.AA;
}
