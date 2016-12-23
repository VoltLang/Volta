//T compiles:yes
//T retval:2
module test;

int main()
{
	int[][] a = [[1, 2, 3]];
	int[][] b = [[0, 0, 0]];
	b[0] = new a[0][0 .. $];
	return  b[0][1];
}
