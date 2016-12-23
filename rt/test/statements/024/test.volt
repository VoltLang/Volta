//T compiles:yes
//T retval:41
module test;

fn main() i32
{
	if (a := 41) {
		return a;
	}
	return 6;
}
