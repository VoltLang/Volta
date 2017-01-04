// Tests float literals and truncating casts.
module test;


fn main() i32
{
	f: f32 = 100.56f;
	return cast(i32)f - 100;
}
