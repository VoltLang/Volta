module test;


class Foo
{
	val: i32;

	fn ichi(v: i32)
	{
		val += v;
	}

	fn ni()
	{
		fn nested()
		{
			val = 1;
			this.val += 4;
			ichi(5);
			this.ichi(5);
		}

		nested();
	}

}

fn main() i32
{
	f := new Foo();
	f.ni();
	return f.val - 15;
}
