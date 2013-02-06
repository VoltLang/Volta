//T compiles:yes
//T retval:0
//T has-passed:no
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
string f7(string) { return null; }

class Main
{
public:
	void[] p1;
	char[] p2;
	int[] p3;
	Struct[] p4;
	Clazz[] p5;
	int*[] p6;
	string p7;

public:
	this(void[], char[], int[], Struct[], Clazz[], int*[], string)
	{
		p1 = null;
		p2 = null;
		p3 = null;
		p4 = null;
		p5 = null;
		p6 = null;
		p7 = null;
		return;
	}

	void func()
	{
		p1 = null;
		p2 = null;
		p3 = null;
		p4 = null;
		p5 = null;
		p6 = null;
		p7 = null;
		return;
	}
}

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

	auto c = new Main(null, null, null, null, null, null);
	c.func();

	return 0;
}
