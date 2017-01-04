// Array allocation and concatenation with new auto.
module test;

fn main() i32
{
	i: i32[] = [0, 1];
	s: string = "volt";

	i2 := new auto(i);
	i3 := new auto(i2, i);

	s2 := new auto(s);
	s3 := new auto(s2, " rox");

	if (s3 == "volt rox" && i3 == [0, 1, 0, 1]) {
		return 0;
	}

	return 1;
}
