module test;


fn func()
{
	val: i32 = 4;
	switch (val) {
	case 3: return other();
	case 5: return other();
	default:
	}
	// Bug, where empty default would cause a unreachable error.
}

fn other() {}

fn main() i32
{
	func();
	return 0;
}
