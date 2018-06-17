//T macro:expect-failure
//T check:foreach over range cannot take an index variable
module main;

fn main() i32 {
	foreach (i, n; 5 .. 10) {
	}
	return 0;
}
