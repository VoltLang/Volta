module test;

class RetRetRetClass
{
	val: i32;

	this(val: i32)
	{
		this.val = val;
	}
}

class RetRetClass
{
	mRetRetRetClass: RetRetRetClass;

	this()
	{
		mRetRetRetClass = new RetRetRetClass(35);
	}

	@property fn propRetClass() RetRetRetClass
	{
		return mRetRetRetClass;
	}
}

class RetClass
{
	mRetRetClass: RetRetClass;

	this()
	{
		mRetRetClass = new RetRetClass();
	}

	fn retClass() RetRetClass
	{
		return mRetRetClass;
	}
}

class MyClass
{
	mRetClass: RetClass;

	this()
	{
		mRetClass = new RetClass();
	}

	@property fn propRetClass() RetClass
	{
		return mRetClass;
	}
}

fn main() i32
{
	myClass := new MyClass();
	return myClass.propRetClass.retClass().propRetClass.val - 35;
}

