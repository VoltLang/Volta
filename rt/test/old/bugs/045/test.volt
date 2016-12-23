//T compiles:yes
module test;

struct Struct
{
	int field;
}

struct Parent
{
	Struct _struct; 

	void memberFunction()
	{
		void nestedFunction()
		{
			_struct.field = 2;
			return;
		}
		return;
	}
}

int main()
{
	return 0;
}

