//T compiles:yes
//T has-passed:no
//T retval:0
// null to array test.
module test_022;

class Clazz
{
	this() { return; }

	int i;
}

struct Struct
{
	int i;
}

void[] f1(void[]) { return null; }
char[] f2(char[]) { return null; }
int[] f3(int[]) { return null; }
Struct[] f4(Struct[]) { return null; }
Clazz[] f5(Clazz[]) { return null; }
int*[] f6(int*[]) { return null; }

int main()
{
	void[] p1 = null;
	char[] p2 = null;
	int[] p3 = null;
	Struct[] p4 = null;
	Clazz p5 = null;
	int*[] p6 = null;

	f1(null);
	f2(null);
	f3(null);
	f4(null);
	f5(null);
	f6(null);

	return 0;
}
