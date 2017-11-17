//T macro:expect-failure
//T check:"blah"
module test;

fn main(args: string[]) i32
{
	str := "blah";
	switch (str) {
	case "blah", "blue", "bloe", "blah", "Blamarama":
		return 1;
	default:
		return 0;
	}
}
