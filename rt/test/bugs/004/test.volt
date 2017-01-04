// Postfixes on things don't work.
module test;


fn main() i32
{
	id := typeid(i32);
	str1 := id.mangledName; // Works

	str2 := typeid(i32).mangledName; // Doesn't
	return 0;
}
