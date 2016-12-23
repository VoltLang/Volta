//T compiles:no
module test;

fn main() i32
{
	token := 0;
	switch (token) {
	case 0:
		v := "label";
		switch (v) {
		case "label":
			return 2;
		default:
			return 6;
		}
		break;
	default:
		assert(false);
	}
	return 12;
}
