//T compiles:yes
//T retval:1
module test;

class Foo {
	int z;
	void writeMarkdownEscaped()
	{
		if (true) {
			auto ff = z;
			void bar() {
			}
		}
	}
}

int main()
{
	return 1;
}

