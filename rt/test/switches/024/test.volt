//T compiles:yes
//T retval:12
module test;

fn main() i32
{
	token := 0;
	switch (token) {
	case 0:
		v := "label";
		switch (v) {
		case "label":
			break;
		default:
			return 6;
		}
		break;
	default:
		assert(false);
	}
	return 12;
}
