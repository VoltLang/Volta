//T compiles:yes
//T retval:32
module test;

int main()
{
	string[string] aa1;
	aa1["hello"] = "hi";
	auto aa2 = new aa1[..];
	aa2["hello"] = "hel";
	return aa1["hello"] == "hi" ? 32 : 17;
}

