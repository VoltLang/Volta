// Test array assign-concatenation.
module test;


fn main() i32
{
	sresult: string = "Volt";
	s2: string = " Watt";

	sresult ~= s2;

	iresult: i32[] = [1, 2];
	i2: i32[] = [3, 4, 5];

	iresult ~= i2;

	if(sresult.length == 9 && iresult.length == 5 && iresult[3] == 4)
		return 0;
	else
		return 42;
}
