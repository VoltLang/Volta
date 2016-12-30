module test;


// Test that the long version is used and 0 and 1 is not
// implicitly converted to bool.
fn func(bool) i32 { return 0; }
fn func(i64) i32 { return 1; }

fn main() i32
{
	return (func(0) + func(1) + func(2)) == 3 ? 0 : 1;
}

