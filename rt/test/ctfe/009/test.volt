module test;

fn x(j: i32) i32
{
	val: i32 = 3;
	switch (j) {
	default:
		val *= 2;
		break;
	case 7:
		val = 0;
		break;
	}
	return val;
}

fn main() i32
{
	return #run x(7);
}
