module theclass;

class Class
{
	field: i32;

	this(val: i32)
	{
		field = val;
	}

	local fn basic() Class
	{
		c := new Class();
		return c;
	}

private:
	this()
	{
		field = 3;
	}
}
