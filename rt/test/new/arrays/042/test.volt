module test;


fn test(cmp: i32) bool
{
	n: i32[2];
	n[1] = 1;
	n1 := n[cmp > 0];
	n2 := n[cast(size_t)(cmp > 0)];
	return n1 != n2;
}

fn main() i32
{
	if (test(-1)) {
		return 1;
	}
	if (test(0)) {
		return 2;
	}
	if (test(1)) {
		return 3;
	}
	return 0;
}
