//T compiles:yes
//T retval:43
module test;

int main()
{
	int[string] aa; aa["a"] = 11; aa["b"] = 32;
	int sum;
	foreach (k, v; aa) {
		sum += v;
	}
	return sum;
}

