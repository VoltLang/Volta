//T compiles:yes
//T retval:12
// AA foreach test with strings as values.
module test;


int main(string[] args)
{
	string[string] aa;

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

	return cast(int)acc;
}
