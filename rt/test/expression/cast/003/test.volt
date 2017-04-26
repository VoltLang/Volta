//T has-passed:no
module test;

// This function forces the cast to be a implicit cast by the argument.
fn test(v: i64) i64
{
	return v;
}

fn main() i32
{
	// The hex literals should not be signed extended.
	// What happens here is that 0xFFFF_FFFF (which is -1)
	// gets sign extended to -1L, but what both D and C
	// does is to just bitcast it to 0x0000_0000_FFFF_FFFF.
	return test(0xFFFF_FFFF) != 0x0000_0000_FFFF_FFFFL;
}
