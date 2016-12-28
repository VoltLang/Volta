// AA dup.
module test;

fn main() i32
{
	aa1: string[string];
	aa1["hello"] = "hi";
	aa2 := new aa1[..];
	aa2["hello"] = "hel";
	return aa1["hello"] == "hi" ? 0 : 1;
}
