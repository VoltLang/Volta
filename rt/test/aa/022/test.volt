// AA foreach test with strings as values.
module test;

fn main() i32
{
	aa: string[string];

	aa["Bernard"] = "foo";
	aa["Jakob"] = "foo";
	aa["David"] = "foo";
	aa["Jim"] = "foo";

	acc : size_t;
	foreach (k, v; aa) {
		if (v.ptr is null) {
			return 77;
		}
		acc += v.length;
	}

	return acc == 12 ? 0 : 1;
}
