module test;

fn f(str: string) i32
{
	switch(str) {
	case "another":
	case "thing":
	case "remove":
	case "f32":
		return 21;
	case "dst":
		return 21;
	default:
	}
	return 4;
}

fn main() i32
{
	return f("dst") - f("remove");
}
