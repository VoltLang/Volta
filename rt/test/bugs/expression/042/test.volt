module test;


enum str1 = "string";
enum string str2 = "string";

fn main() i32
{
	arr: string[] = new string[](3);

	// Both of these fails
	arr ~= str1;
	arr ~= str2;

	return 0;
}
