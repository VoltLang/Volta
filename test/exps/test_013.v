//T compiles:yes
//T retval:5
//T has-passed:no
module test_013;

int main()
{
	bool True = true;
	bool False = false;
	int val;

	val += cast(int)(true);
	val += cast(int)(!false);
	val += cast(int)(True);
	val += cast(int)(!False);
	val += cast(int)(True == !False);
	return val;
}
