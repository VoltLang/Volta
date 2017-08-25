//T macro:do-not-link
module test;

struct StringHolder
{
	a: i32;
}

fn main() i32
{
	sh: StringHolder;
	sh.a = 15;
	a: i32[StringHolder];
	a[sh] = 12;
	a.remove(sh);
	return a[sh];
}

