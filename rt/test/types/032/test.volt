//T compiles:yes
//T retval:17
module test;


global size_t counter;

void func(scope const(char)[] str)
{
	counter += str.length;
}

void otherFunc(scope const(char)[] str)
{
	func(str);
}

int main()
{
	char[] str1 = new char[](1);
	scope const(char)[] str2 = new char[](2);

	const(char)[] str4 = "four";
	string str9 = "nine99999";

	func(str1);
	otherFunc(str1);
	func(str2);
	func(str4);
	func(str9);

	return cast(int)counter;
}
