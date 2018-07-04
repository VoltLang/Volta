module main;

class Foo!(T)
{
	fn foo() T
	{
		return 6;
	}
}

class LinkedList!(T) : IntegerFoo
{
private:
	mData: T;
	mNext: LinkedList;

public:
	this()
	{
	}

	this(val: T)
	{
		mData = val;
	}

public:
	fn length() size_t
	{
		current := mNext;
		count: size_t;
		while (current !is null) {
			count++;
			current = current.mNext;
		}
		return count;
	}

	fn add(val: T)
	{
		if (mNext is null) {
			mNext = new LinkedList(val);
			return;
		}
		current := mNext;
		while (current !is null) {
			if (current.mNext is null) {
				current.mNext = new LinkedList(val);
				return;
			}
			current = current.mNext;
		}
	}

	fn iterate(cb: scope dg(T))
	{
		current := mNext;
		while (current !is null) {
			cb(current.mData);
			current = current.mNext;
		}
	}
}

class IntegerFoo  = Foo!i32;
class IntegerList = LinkedList!i32;

class AddOneList : IntegerList
{
public:
	this() { super(); }
	this(val: i32) { super(val); }

public:
	override fn add(val: i32)
	{
		super.add(val + 1);
	}

	override fn foo() i32
	{
		return super.foo() * 2;
	}
}

fn main() i32
{
	checkVal := 1;
	checkCounter := 0;
	fn printInteger(val: i32) {if (checkVal++ == val) { checkCounter++; }}
	il := new AddOneList();
	il.add(0);
	il.add(1);
	il.add(2);
	if (il.length() != 3) {
		return 1;
	}
	il.iterate(printInteger);
	return checkCounter - 3 + (12 - il.foo());
}
