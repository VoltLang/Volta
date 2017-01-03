// Simple static functions.
module test;

struct Maths
{
	local fn Glozum(a: i32) i32
	{
		return a * 2;
	}

	global fn Shoble(a: i32) i32
	{
		return a;
	}
}

fn main() i32
{
	return Maths.Glozum(10) + Maths.Shoble(23) - 43;
}
