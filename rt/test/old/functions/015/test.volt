//T compiles:yes
//T retval:5
module test;

fn div(a : i32, b : i32) i32 {
	return a / b;
}

fn main() i32 {
	return div(b:2, a:10);
}
