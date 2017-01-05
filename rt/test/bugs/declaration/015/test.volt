module test;

fn main() i32
{
	aa: string[string];
	ap: int[string];
	pa: string[int];
	pp: int[int];
	aa["apple"] = "thursday";
	ap["banana"] = 2;
	pa[42] = "orange";
	pp[-1] = 3;
	return cast(i32) aa.get("apple", "abc").length +
		ap.get("banana", 2) +
		cast(i32) pa.get(42, "").length +
		pp.get(-1, 7) - 19;
}

