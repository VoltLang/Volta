// Default case.
module test;

fn main() i32
{
	switch ("BANANA") {
	case "apple":
		return 1;
	case "banana":
		return 7;
	case "mango":
		return 9;
	default:
		return 0;
	}
}
