module test;

struct Foo!(K, V)
{
	union Elm
	{
		key: K;
		value: V;
	}
}

struct Instance = mixin Foo!(i32, i16);
struct Instance2 = mixin Foo!(f32, f32);

fn main() i32
{
	d: Instance.Elm;
	return d.key;
}
