module test;

@property fn foo() size_t[]
{
	return [cast(size_t)0, 41U];
}

fn main() i32
{
	foreach (i, e; foo) {
		if (e > 0) {
			return cast(i32)(i + e) - 42;
		}
	}

	return 5;
}
