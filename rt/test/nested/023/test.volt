//T compiles:yes
//T retval:42
module test;


struct Foo
{
	int i;
}

int main()
{
	int[] arr;
	foreach (e; arr) {
		void nest() {
			foreach (e; arr) {
			}
			Foo f = { e };
		}
	}
	return 42;
}
