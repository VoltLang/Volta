//T compiles:yes
//T retval:6
module test;

fn setA(ref a : i32) void {
	a = 2;
}

fn setB(out b : i32) void {
	b = 4;
}

i32 main() {
	i32 c, d;
	setA(ref c);
	setB(out d);
	return c + d;
}
