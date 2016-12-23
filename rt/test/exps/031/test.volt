//T compiles:yes
//T retval:35
module test;

class RetRetRetClass
{
	int val;

	this(int val)
	{
		this.val = val;
		return;
	}
}

class RetRetClass
{
	RetRetRetClass mRetRetRetClass;

	this()
	{
		mRetRetRetClass = new RetRetRetClass(35);
		return;
	}

	@property RetRetRetClass propRetClass()
	{
		return mRetRetRetClass;
	}
}

class RetClass
{
	RetRetClass mRetRetClass;

	this()
	{
		mRetRetClass = new RetRetClass();
		return;
	}

	RetRetClass retClass()
	{
		return mRetRetClass;
	}
}

class MyClass
{
	RetClass mRetClass;

	this()
	{
		mRetClass = new RetClass();
		return;
	}

	@property RetClass propRetClass()
	{
		return mRetClass;
	}
}

int main()
{
	auto myClass = new MyClass();
	return myClass.propRetClass.retClass().propRetClass.val;
}

