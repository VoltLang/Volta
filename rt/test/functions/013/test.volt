//T compiles:no
module test;

fn add(a : i32, b : i32 = 2) (i32, i64) {
	return a + b;
}

i32 main() {
	return add(12, 2) + add(12);
}
