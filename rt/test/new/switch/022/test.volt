module test;

fn f(str: string) i32
{
	switch(str) {
	case "remove":
	case "f32":
		return 21;
	case "dst":
		return 21;
	default:
		return 4;
	}
}

fn main() i32
{
	return f("dst") - f("remove");
}
