// null to pointer test.
module test;


alias voidPtr = void*;

class Clazz
{
	this() {}

	i: i32;
}

struct Struct
{
	i: i32;
}

fn f1(void*) void*
{
	return null;
}

fn f2(char*) char*
{
	return null;
}

fn f3(i32*) i32*
{
	return null;
}

fn f4(Struct*) Struct*
{
	return null;
}

fn f5(Clazz) Clazz
{
	return null;
}

fn f6(voidPtr) voidPtr
{
	return null;
}

class Main
{
	public:
		p1: void*;
		p2: char*;
		p3: i32*;
		p4: Struct*;
		p5: Clazz;
		p6: voidPtr;

	public:
		this(void*, char*, int*, Struct*, Clazz, voidPtr)
		{
			p1 = null;
			p2 = null;
			p3 = null;
			p4 = null;
			p5 = null;
			p6 = null;
		}

		fn func()
		{
			p1 = null;
			p2 = null;
			p3 = null;
			p4 = null;
			p5 = null;
			p6 = null;
		}
}

fn main() i32
{
	p1: void* = null;
	p2: char* = null;
	p3: i32* = null;
	p4: Struct* = null;
	p5: Clazz = null;

	f1(null);
	f2(null);
	f3(null);
	f4(null);
	f5(null);
	f6(null);

	c := new Main(null, null, null, null, null, null);
	c.func();

	return 0;
}
