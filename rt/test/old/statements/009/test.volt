//T compiles:yes
//T retval:3
module test;

int main()
{
	bool b = true;
	int x;
	int* v;
	if (auto p = b) {
		x++;
	}
	if (auto p = &x) {
		v = p;
		x++;
	}
	if (auto p = &x) {
		v = p;
		x++;
	}
	return x;
}

