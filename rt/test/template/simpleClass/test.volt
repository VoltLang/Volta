module main;

class LinkedList!(T)
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

class IntegerList = LinkedList!i32;

fn main() i32
{
	checkVal := 1;
	checkCounter := 0;
	fn printInteger(val: i32) {if (checkVal++ == val) { checkCounter++; }}
	il := new IntegerList();
	il.add(1);
	il.add(2);
	il.add(3);
	if (il.length() != 3) {
		return 1;
	}
	il.iterate(printInteger);
	return checkCounter - 3;
}
