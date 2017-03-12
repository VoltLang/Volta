//T default:no
//T macro:do-not-link
module test;

struct StringHolder
{
	a: string;
}

fn main() i32
{
	sh: StringHolder;
	sh.a = "hello";
	a: i32[StringHolder];
	a[sh] = 12;
	a.remove(sh);
	return a[sh];
}

