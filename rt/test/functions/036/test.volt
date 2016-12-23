//T compiles:no
module test;

import core.stdc.stdio;

fn case1(dg: void delegate(string))
{
}

fn case2(dg: void delegate(scope const(char)[]))
{
}

fn main() i32
{
	string ss;
	fn f1(s: string) {
		ss = s;
	}

	case1(f1);  // Okay.
	case2(f1);  // Bad.
	/* The case2 function expects to be able to reuse the memory for
	 * the array, but f1 expects to be able to keep references.
	 */
	
	fn f2(s: scope const(char)[]) {
		printf("%*.s", cast(int)s.length, s.ptr);
	}

	case1(f2);  // Okay.
	case2(f2);  // Okay.

	return 0;
}
