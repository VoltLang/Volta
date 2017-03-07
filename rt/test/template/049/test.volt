module test;

struct Foo!(K, V)
{
	a: K;
	b: V;
	alias F = K;
}

struct Instance = mixin Foo!(i32, i16);
struct Instance2 = mixin Foo!(f32, f64);

fn main() i32
{
	d: Instance;
	val: Instance.F;
	val = d.a;
	return val;
}
