//T macro:abi
//T check:define i32 @ADD_TWO_INTEGERS(i32, i32) #0 {
//T requires:sysvamd64
module test;

extern (C) fn ADD_TWO_INTEGERS(a: i32, b: i32) i32
{
	return a + b;
}
