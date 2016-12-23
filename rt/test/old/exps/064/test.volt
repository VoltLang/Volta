//T compiles:yes
//T retval:4
module test;

int main()
{
	string s = `\`;
	string ss = "\''";
	string sss = r"\";
	return cast(int) (s.length + ss.length + sss.length);
}
