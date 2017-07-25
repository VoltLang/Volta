//T default:no
//T macro:expect-failure
module test;

fn main() i32
{
	str := "hello";
	switch (str) {
	case "hello":
		return 1;
	case "hello":
		return 2;
	default:
		return 0;
	}
}
