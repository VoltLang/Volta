module test;

struct S
{
	i: i32;
}

fn main() i32
{
	string s = "bar";
	x := 1;	
	switch (x) {
	default:
		assert(false);
	case 2:
		x += 12;
		break;
	case 1:
		goto case 2;
	}
	switch (s) {
	case "bar":
		x -= 13;
		goto case "foo";
	case "baz":
		return 15;
	case "ban":
		return x;
	default:
		return 2;
	case "foo":
		goto case "ban";
	}
}
