//T compiles:yes
//T retval:42
module test;

extern(C) fn malloc(size_t) void*;
extern(C) fn free(void*);


class Super
{
public:
	int val;

public:
	this(int val)
	{
		this.val += val;
	}

	void add()
	{
		// This function should not be run.
		val += 4;
	}

	void other()
	{
		// This function should be run.
		val += 1;
	}
}

class Base : Super
{
public:
	this()
	{
		super(10);
		this.val += 10;
	}

	~this()
	{
		// This should be 41 now.
		// Super._ctor  +10  10
		// Base._ctor   +10  20
		// Base.add     +20  40
		// Super.other   +1  41
		ret = val + 1;
		// And now ret should be 42.
	}

	override void add()
	{
		val += 20;
	}
}


global int ret;


void func(Super s)
{
	s.add();
	s.other();
}

Base allocBase()
{
	auto ti = typeid(Base);
	auto ptr = malloc(ti.classSize);

	ptr[0 .. ti.classSize] = ti.classInit[0 .. ti.classSize];

	return cast(Base)ptr;
}

void freeBase(ref Base b)
{
	free(cast(void*)b);
	b = null;
}

int main()
{
	auto b = allocBase();

	b.__ctor();

	func(b);

	// Pick up val early.
	// If the wrong dtor is run it will be the wrong value.
	ret = b.val;

	b.__dtor();

	freeBase(ref b);

	return ret;
}
