//Simple static array test.
module test;


fn main() i32
{
	arg: i32[4];
	arg[0] = 18;
	arg[1] = 16;

	arr := arg[];
	ptr := arg.ptr;

	return (arr[0] + ptr[1] + cast(int)arg.length + cast(int)arr.length == 42) ? 0 : 1;
}
