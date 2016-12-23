//T compiles:yes
//T retval:42
module test;

import core.typeinfo : TypeInfo, ClassInfo;

class Parent {}
class Child : Parent {}

int main()
{
	int var;
	Parent p = new Parent();
	Child c = new Child();

	auto tiInt = typeid(int);
	auto ti1 = typeid(p);
	auto ti2 = typeid(c);
	auto ci1 = p.classinfo;
	auto ci2 = c.classinfo;

	// Currently int does not have its own TypeInfo type.
	static is (typeof(tiInt) == TypeInfo);

	// typeid for Classes return ClassInfo, because it inherits.
	// XXX not now
	//static is (typeof(ti1) == ClassInfo);
	//static is (typeof(ti2) == ClassInfo);

	// This is pretty logical.
	static is (typeof(ci1) == ClassInfo);
	static is (typeof(ci2) == ClassInfo);


	// These should be differnt, because type Parent is not Child.
	assert(ci1 !is ci2);

	// typeid should be the same as classinfo for a class.
	// Right now p points to a Parent.
	assert(ti1 is ci1);

	// typeid should be the same as classinfo for a class.
	// Right now c points to a Child.
	assert(ti2 is ci2);

	// typeid should not be dynamic.
	// Update p reference to point at a child.
	p = c;
	auto test1 = typeid(p);
	assert(test1  is ci1);
	assert(test1 !is ci2);

	// classinfo should be dynamic.
	// Update p reference to point at a child.
	p = c;
	auto test2 = p.classinfo;
	assert(test2 !is ci1);
	assert(test2  is ci2);

	return 42;
}
