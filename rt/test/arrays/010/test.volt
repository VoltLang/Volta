// Test array concatenation.
module test;


fn main() i32
{
	s1: string = "Volt";
	s2: string = " Watt";

	sresult: string = s1 ~ s2;

	i1: i32[] = [1, 2];
	i2: i32[] = [3, 4, 5];

	iresult: i32[] = i1 ~ i2;

	if(sresult.length == 9 && iresult.length == 5 && iresult[3] == 4)
		return 0;
	else
		return 42;
}
