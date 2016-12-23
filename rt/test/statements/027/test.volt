//T compiles:yes
//T retval:1
module test;

fn main() i32
{
	b := false;
	if (!false) {
		return 1;
	}
	if (!b) {
		return 2;
	}
	return 0;
}
