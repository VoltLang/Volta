// Test array comparison.
module test;


fn main() i32
{
	s1: string = "Volt";
	s2: string = "Watt";
	s3: string = "Tesla";

	i1: i32[] = [1, 2];
	i2: i32[] = [3, 4, 5];
	i3: i32[] = [6, 7, 8];

	if(s1 == s1 && s1 != s2 && s2 != s3 && !(s1 == s2) &&
	   i1 == i1 && i1 != i2 && i2 != i3 && !(i1 == i2))
		return 0;
	else
		return 42;
}
