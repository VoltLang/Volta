// Array literal comparison in switch with i64 arrays.
module test;

int main() {
	foo: i64[] = [cast(i64)3, 3];
	switch (foo) {
	case [cast(i64)1, 1]:
		return 1;
	case [cast(i64)2, 2]:
		return 2;
	case [cast(i64)3, 3]:
		return 0;
	default:
		return 4;
	}
}
