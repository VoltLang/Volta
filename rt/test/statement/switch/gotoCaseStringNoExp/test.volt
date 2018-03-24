module main;

fn main() i32
{
	i := ".gz";
	switch (i) {
	case ".gz":
		goto case;
	case ".tgz":
		goto case "theCorrectString";
	case "anotherIncorrectString":
		return 3;
	case "theCorrectString":
		return 0;
	default:
		return 2;
	}
}
