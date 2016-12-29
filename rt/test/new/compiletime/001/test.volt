// Most basic conditional test.
module test;


version (Volt) {
	local val: i32;
}
version (none) {
	val: i32;
}

fn main() i32
{
	version (Volt) {
		val = 0;
	}
	version (none) {
		val = 32;
	}

	return val;
}
