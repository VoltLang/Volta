// Consecutive AA declarations.
module test;

int main()
{
	aa: i32[string];
	bb: i32[string];
	aa["hello"] = 42;
	return aa.length + bb.length == 1 ? 0 : 1;
}
