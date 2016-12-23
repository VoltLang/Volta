//T compiles:yes
//T retval:0
module test;

fn main() i32
{
	str : string = "hello";
	foreach (d : dchar; str) {
	}
	return 0;
}
