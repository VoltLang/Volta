//T compiles:yes
//T retval:6
module test;

int main()
{
	auto arr = [[1, 2, 3],[4, 5, 6]];
	return arr[$-1][$-1];
}
