module test;

struct Foo!(K, V)
{
	struct Elm
	{
		struct ElmElm
		{
			key: K;
			value: V;

			fn foo() i32
			{
				return cast(i32)key + cast(i32)value;
			}
		}
	}
}

struct Instance = mixin Foo!(i32, i32);
struct Instance2 = mixin Foo!(f32, f32);

fn main() i32
{
	d: Instance.Elm.ElmElm;
	return d.foo();
}
