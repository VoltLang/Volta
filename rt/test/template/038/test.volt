module test;

struct Foo!(K, V)
{
	struct Elm
	{
		key: K;
		value: V;
	}
}

struct Instance = mixin Foo!(i32, i16);

fn main() i32
{
	d: Instance.Elm;
	return d.key;
}
