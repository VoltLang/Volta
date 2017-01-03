//T default:no
//T macro:expect-failure
//T check:static function via instance
// Test accessing static functions through instance members.
module test;

struct Maths
{
	global fn Shoble(a: i32) i32
	{
		return a;
	}
}

fn main() i32
{
	maths: Maths;
	return maths.Shoble(23);
}
