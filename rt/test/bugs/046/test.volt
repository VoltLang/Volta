module test;

struct EmptyStruct
{
	// The problem exist(ed) without this field,
	// but this makes it a compiles:yes, which is preferable.
	o: i32;
}

struct Parent
{
	es: EmptyStruct;

	fn func()
	{
		fn nested()
		{
			return;
		}

		if (true) {
			es.o = 0;
		}

		return;
	}
}

fn main() i32
{
	return 0;
}

