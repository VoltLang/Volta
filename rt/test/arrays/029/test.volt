//T compiles:yes
//T retval:42
// Array allocation and concatenation with new auto.
module test;

int main()
{
	int[] i = [0, 1];
	string s = "volt";

	auto i2 = new auto(i);
	auto i3 = new auto(i2, i);

	auto s2 = new auto(s);
	auto s3 = new auto(s2, " rox");

	if (s3 == "volt rox" && i3 == [0, 1, 0, 1]) {
		return 42;
	}

	return 1;
}
