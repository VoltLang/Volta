// The nested transforms should not interfere with implicit casting.    
module test;

fn main() i32
{
	x: i64 = 4;
	fn func() i16 { return cast(i16)(12 + x); }
	return func() - 16;
}
