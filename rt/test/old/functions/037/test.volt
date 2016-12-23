//T compiles:yes
//T retval:0
module test;

extern(C) fn printf(const(char)*, ...) int;


fn case1(dgt: void delegate(string))
{
}

fn case2(dgt: void delegate(scope const(char)[]))
{
}

fn main() i32
{
	string ss;
	fn f1(s: string) {
		ss = s;
	}

	case1(f1);  // Okay.
	
	fn f2(s: scope const(char)[]) {
		printf("%*.s", cast(int)s.length, s.ptr);
	}

	case1(f2);  // Okay.
	case2(f2);  // Okay.

	return 0;
}
