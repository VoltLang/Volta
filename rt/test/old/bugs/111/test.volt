//T compiles:yes
//T retval:42
module test;


enum str1 = "string";
enum string str2 = "string";

int main()
{
	string[] arr = new string[](3);

	// Both of these fails
	arr ~= str1;
	arr ~= str2;

	return 42;
}
