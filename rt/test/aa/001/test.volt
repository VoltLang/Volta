// Basic AA test.
module test;

int main()
{
	aa: i32[i32];
	aa[3] = 42;
	return aa[3] == 42 ? 0 : 1;
}
