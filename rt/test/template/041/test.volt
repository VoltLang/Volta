module test;

struct Foo!(K, V)
{
	class Elm
	{
		this()
		{
			key = 3;
		}
	
		key: K;
		value: V;
	}
}

struct Instance = mixin Foo!(i32, i16);
struct Instance2 = mixin Foo!(f32, f32);

fn main() i32
{
	d := new Instance.Elm();
	return d.key - 3;
}
