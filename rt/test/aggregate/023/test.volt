// Union test.
module test;


union Test
{
	i: i32;
	u: u32;
	l: i64;
}

fn main() i32
{
	tid := typeid(Test);

	t: Test;
	t.i = -1;
	if (tid.size == 8 && t.u == cast(u32)-1) {
		return 0;
	}
	return 42;
}
