//T compiles:yes
//T retval:15
module test;


class Foo
{
	int val;

	void ichi(int v)
	{
		val += v;
	}

	void ni()
	{
		void nested()
		{
			val = 1;
			this.val += 4;
			ichi(5);
			this.ichi(5);
		}

		nested();
	}

}

int main()
{
	auto f = new Foo();
	f.ni();
	return f.val;
}
