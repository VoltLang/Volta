module test;

fn main() i32
{
	nullStr: string;
	if ("aaaa" != "aaaa") return 1;
	if ("aa" >= "aaaa") return 2;
	if ("aaaa" <= "aa") return 3;
	if (nullStr >= "aaaa") return 4;
	if ("aaaa" <= nullStr) return 5;
	if (nullStr != nullStr) return 6;
	if ("aaaa" >= "bbbb") return 7;
	if ("bbbb" <= "aaaa") return 8;
	if ("aaaa" >= "b") return 9;
	if ("b" <= "aaaa") return 10;

	nullStrStr: string[];
	if (["aa", "aa"] != ["aa", "aa"]) return 11;
	if (["aa"] >= ["aa", "aa"]) return 12;
	if (["aa", "aa"] <= ["aa"]) return 13;
	if (nullStrStr >= ["aa", "aa"]) return 14;
	if (["aa", "aa"] <= nullStrStr) return 15;
	if (["aa", "aa"] >= ["bb", "aa"]) return 16;
	if (["bb", "aa"] <= ["aa", "aa"]) return 17;
	if (["aa", "aa"] >= ["b"]) return 18;
	if (["b"] <= ["aa", "aa"]) return 19;

	return 0;
}

