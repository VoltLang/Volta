// Tests correct functioning of typeof.
module test;


fn main() i32
{
	i: i32 = 1;
	AnInteger: typeof(i++) = 41;  // i should not mutate.
	return (AnInteger + i) - 42;
}
