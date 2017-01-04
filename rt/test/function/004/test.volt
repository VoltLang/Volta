module test;


fn func(t: bool, out f: i32)
{
	if (t) {
		f = 32;
	}
}

fn main() i32
{
	f: i32;
	func(true, out f);
	// This second call doesn't touch f and should return set f to 0.
	func(false, out f);
	return f;
}
