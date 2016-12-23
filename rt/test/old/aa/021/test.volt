//T compiles:no
module test;

int main()
{
	auto obj = new object.Object();
	int[object.Object] aa;
	aa[obj] = 12;
	return aa[obj];
}
