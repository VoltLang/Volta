module test;


enum i32[4] foo   = [ 1, 0, 0, 0 ];

global bar: i32[4] = [ 0, 2, 0, 0 ];

enum i32[] fiz    = [ 0, 0, 3, 0 ];

global biz: i32[]  = [ 0, 0, 0, 4 ];

fn main() i32
{
	return foo[0] + bar[1] + fiz[2] + biz[3] - 10;
}
