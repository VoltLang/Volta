//T compiles:yes
//T retval:6
module test;

global this()
{
	x = 2;
}

static int x;
static string[] a = ["hi"];
static string[] b = ["hi"];

int main()
{
	return x + cast(int)a[0].length + cast(int)b[0].length;
}
