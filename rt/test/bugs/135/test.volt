//T compiles:yes
//T retval:1
module test;

fn main() i32
{
	str := "hi";
	aBool := true;
	aa1: i32[string];
	aa1["hi"] = 1;
	aa2: i32[string];
	c := str in (aBool ? aa1 : aa2);
	return *c;
}
