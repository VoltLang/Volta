//T compiles:yes
//T retval:6
module test;

fn multIntegers(i : i32, j : i32) i32
{
	return i * j;
}

fn main() i32
{
	fp : fn!Volt (i32, i32) i32 = multIntegers;
	return fp(3, 2);
}
