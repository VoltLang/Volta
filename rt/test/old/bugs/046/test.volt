//T compiles:yes
//T retval:0
module test;

struct EmptyStruct
{
	// The problem exist(ed) without this field,
	// but this makes it a compiles:yes, which is preferable.
	int o;
}

struct Parent
{
	EmptyStruct es;

	void func()
	{
		void nested()
		{
			return;
		}

		if (true) {
			es.o = 0;
		}

		return;
	}
}

int main()
{
	return 0;
}

