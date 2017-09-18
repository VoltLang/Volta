module test;

struct A = mixin AllocHashMap!();
struct B = mixin AllocHashMap!();

struct AllocHashMap!()
{
	fn funcOne()
	{
		index := funcTwo();
		for (;; ++index) {
		}
	}

	fn funcTwo() i32
	{
		return 0;
	}
}

fn main() i32
{
	return 0;
}
