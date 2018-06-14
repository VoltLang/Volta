module main;

fn main() i32 {
	a := 2;
	b := 128;
	a <<= 1;
	b >>= a;
	b >>>= 1;
	return b - 4;
}
