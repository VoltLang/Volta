module test;


global counter: size_t;

fn func(str: scope const(char)[])
{
	counter += str.length;
}

fn otherFunc(str: scope const(char)[])
{
	func(str);
}

fn main() i32
{
	str1: char[] = new char[](1);
	str2: scope const(char)[] = new char[](2);

	str4: const(char)[] = "four";
	str9: string = "nine99999";

	func(str1);
	otherFunc(str1);
	func(str2);
	func(str4);
	func(str9);

	return cast(i32)counter - 17;
}
