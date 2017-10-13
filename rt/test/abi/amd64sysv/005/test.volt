//T macro:abi
//T check:define float @ADD_TWO_FLOATS(float, float) #0 {
//T requires:sysvamd64
module test;

extern (C) fn ADD_TWO_FLOATS(a: f32, b: f32) f32
{
	return a + b;
}
