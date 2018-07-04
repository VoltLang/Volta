module main;

interface IStack!(T)
{
	fn length() size_t;
	fn pop() T;
	fn push(T);
}

interface IIntegerStack = IStack!i32;

class SimpleStack : IIntegerStack
{
	array: i32[];

	override fn length() size_t
	{
		return array.length;
	}

	override fn pop() i32
	{
		v := array[$-1];
		array = array[0 .. $-1];
		return v;
	}

	override fn push(val: i32)
	{
		array ~= val;
	}
}

fn sum(istack: IIntegerStack) i32
{
	sum: i32;
	while (istack.length() > 0) {
		sum += istack.pop();
	}
	return sum;
}

fn main() i32
{
	auto ss = new SimpleStack();
	ss.push(5); ss.push(3); ss.push(-2); ss.push(12);
	return sum(ss) - 18;
}
