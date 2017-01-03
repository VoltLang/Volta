module test;

fn main() i32
{
	fn func() i32 { return 0; }
	dgt: scope dg() i32 = func;
	return dgt();
}
