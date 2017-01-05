// Array copy to little.
module test;


fn main() i32
{
	a1 := new i32[](4);
	a2 := new i32[](4);

	a1[2] = 4;
	a2[2] = 42;

	a1[] = a2;
 
	return a1[2] - 42;
}
