//T compiles:yes
//T retval:0
module test;

void writeMarkdownEscaped()
{
	int[] y;
	foreach (x; y) {
		auto b = x;
		void foo() {
		}
	}
	if (true) {
		int z;
		auto ff = z;
		void bar() {
		}
	}
}

int main()
{
	return 0;
}

