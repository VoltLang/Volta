module test;

fn main() i32
{
	aa: i32[string]; aa["a"] = 11; aa["b"] = 32;
	sum: i32;
	foreach (k, v; aa) {
		sum += v;
	}
	return sum - 43;
}

