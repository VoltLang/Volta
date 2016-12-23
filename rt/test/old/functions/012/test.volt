//T compiles:yes
//T retval:28
module test;

fn add(a : i32, b : i32 = 2) (i32) {
	return a + b;
}

i32 main() {
	return add(12, 2) + add(12);  // 28
}
