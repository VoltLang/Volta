//T compiles:yes
//T retval:19
module test;

int main()
{
	string[string] aa;
	int[string] ap;
	string[int] pa;
	int[int] pp;
	aa["apple"] = "thursday";
	ap["banana"] = 2;
	pa[42] = "orange";
	pp[-1] = 3;
	return cast(int) aa.get("apple", "abc").length +
		ap.get("banana", 2) +
		cast(int) pa.get(42, "").length +
		pp.get(-1, 7);
}

