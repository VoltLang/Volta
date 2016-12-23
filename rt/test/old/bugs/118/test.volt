//T compiles:yes
//T retval:10
module test;


enum int[4] foo   = [ 1, 0, 0, 0 ];

global int[4] bar = [ 0, 2, 0, 0 ];

enum int[] fiz    = [ 0, 0, 3, 0 ];

global int[] biz  = [ 0, 0, 0, 4 ];

int main()
{
	return foo[0] + bar[1] + fiz[2] + biz[3];
}
