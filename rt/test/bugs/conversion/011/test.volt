//T default:no
//T macro:expect-failure
//T check:implicitly convert
module test;

class S
{
	dgt: dg(i32, i32) i32;

	fn add(a: i32, b: i32) i32
	{
		return a + b;
	}
}

fn main() i32
{
	s := new S();
	s.dgt = s.add;
	return s.dgt("potato", false);
}

