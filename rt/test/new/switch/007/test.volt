// Switch on string.
module test;

fn main() i32
{
	switch ("banana") {
	case "apple":
		return 1;
	case "banana":
		return 0;
	case "mango":
		return 9;
	default:
		return 12;
	}
}

