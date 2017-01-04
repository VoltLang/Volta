module test;

fn main() i32
{
	dg1 := cast(dg()) null;
	dg2: dg();
	if (dg1 is null && dg2 is null) {
		return 0;
	}
	return 17;
}

